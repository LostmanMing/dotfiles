#!/usr/bin/env python3
import argparse
import json
import os
import re
import stat
import sys
import tempfile
from collections import Counter
from datetime import date, timedelta
from html.parser import HTMLParser
from pathlib import Path

SKILL_NAME = "keep-weekly-notes"
SCHEMA_VERSION = 1
WEEK_RE = re.compile(r"^\d{4}-W\d{2}$")
PLACEHOLDER_RE = re.compile(r"\{\{[A-Z0-9_]+\}\}")
ACTIVE_URL_RE = re.compile(r"^(?:data|javascript|vbscript):", re.IGNORECASE)
FORBIDDEN_TAGS = {
    "script",
    "iframe",
    "frame",
    "frameset",
    "form",
    "object",
    "embed",
    "link",
    "base",
    "audio",
    "video",
    "source",
    "track",
}
RESOURCE_ATTRIBUTES = {"src", "srcset", "action", "formaction", "poster", "background"}


def config_path() -> Path:
    raw_base = os.environ.get("XDG_CONFIG_HOME")
    base = Path(raw_base).expanduser() if raw_base else Path.home() / ".config"
    if not base.is_absolute():
        raise ValueError("XDG_CONFIG_HOME must be an absolute path")
    base = base.resolve(strict=False)
    repo = repository_root()
    if is_within(base, repo):
        raise ValueError(f"XDG_CONFIG_HOME must be outside dotfiles repository: {repo}")
    return base / SKILL_NAME / "config.json"


def repository_root() -> Path:
    return Path(__file__).resolve().parents[3]


def is_within(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def load_config() -> dict:
    path = config_path()
    if not path.is_file():
        raise FileNotFoundError(path)
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"invalid config: {exc}") from exc
    if data.get("schema_version") != SCHEMA_VERSION:
        raise ValueError("unsupported config schema_version")
    output_root = data.get("output_root")
    if not isinstance(output_root, str):
        raise ValueError("config output_root must be an absolute path")
    data["output_root"] = str(normalize_output_root(output_root))
    return data


def normalize_output_root(raw: str) -> Path:
    candidate = Path(raw).expanduser()
    if not candidate.is_absolute():
        raise ValueError("output_root must be an absolute path")
    candidate = candidate.resolve(strict=False)
    repo = repository_root()
    if is_within(candidate, repo):
        raise ValueError(f"output_root must be outside dotfiles repository: {repo}")
    return candidate


def save_config(output_root: Path) -> Path:
    output_existed = output_root.exists()
    output_root.mkdir(mode=0o700, parents=True, exist_ok=True)
    if not output_root.is_dir():
        raise ValueError("output_root is not a directory")
    if output_existed:
        mode = stat.S_IMODE(output_root.stat().st_mode)
        if mode & 0o077:
            raise ValueError(f"existing output_root must be private (chmod 700): {mode:04o}")
    else:
        output_root.chmod(0o700)

    path = config_path()
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    path.parent.chmod(0o700)
    payload = {"schema_version": SCHEMA_VERSION, "output_root": str(output_root)}
    fd, temporary = tempfile.mkstemp(prefix=".config.", dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
        path.chmod(0o600)
    except Exception:
        try:
            os.close(fd)
        except OSError:
            pass
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise
    return path


def parse_day(raw: str | None) -> date:
    if raw is None:
        return date.today()
    try:
        return date.fromisoformat(raw)
    except ValueError as exc:
        raise ValueError("date must use YYYY-MM-DD") from exc


def week_info(day: date, output_root: Path) -> dict:
    iso = day.isocalendar()
    week_id = f"{iso.year:04d}-W{iso.week:02d}"
    start = day - timedelta(days=iso.weekday - 1)
    end = start + timedelta(days=6)
    week_dir = output_root / week_id
    return {
        "week_id": week_id,
        "week_start": start.isoformat(),
        "week_end": end.isoformat(),
        "week_dir": str(week_dir),
        "html_path": str(week_dir / "index.html"),
    }


class NotesHTMLParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.charset = False
        self.viewport = False
        self.main_weeks: list[str | None] = []
        self.topics: list[dict[str, object]] = []
        self.nav_targets: list[str] = []
        self.forbidden: list[str] = []
        self.external_references: list[str] = []
        self.structure_errors: list[str] = []
        self._nav_depth = 0
        self._article: dict[str, object] | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        lower_tag = tag.lower()
        if lower_tag in FORBIDDEN_TAGS:
            self.forbidden.append(lower_tag)
        if lower_tag == "meta":
            if values.get("charset", "").lower() == "utf-8":
                self.charset = True
            if values.get("name", "").lower() == "viewport":
                self.viewport = True
            if values.get("http-equiv", "").lower() == "refresh":
                self.forbidden.append("meta[http-equiv=refresh]")
        if lower_tag == "main":
            self.main_weeks.append(values.get("data-week"))
        if lower_tag == "nav":
            self._nav_depth += 1
        if self._nav_depth and lower_tag == "a":
            href = values.get("href", "")
            if href.startswith("#") and len(href) > 1:
                self.nav_targets.append(href[1:])
        if lower_tag == "article":
            if self._article is not None:
                self.structure_errors.append("nested article elements are not allowed")
            self._article = {
                "id": values.get("id"),
                "topic": values.get("data-topic"),
                "sections": set(),
                "text": [],
            }
            self.topics.append(self._article)
        elif self._article is not None and lower_tag == "section":
            sections = self._article["sections"]
            if isinstance(sections, set):
                sections.update(values.get("class", "").split())

        for name, value in attrs:
            lower_name = name.lower()
            value = value or ""
            if lower_name.startswith("on"):
                self.forbidden.append(f"{lower_tag}[{name}]")
            if lower_name == "href":
                if value and (not value.startswith("#") or ACTIVE_URL_RE.search(value)):
                    self.external_references.append(f"{lower_tag}[{name}={value}]")
            elif lower_name in RESOURCE_ATTRIBUTES or lower_name.endswith(":href"):
                if value:
                    self.external_references.append(f"{lower_tag}[{name}={value}]")
            if lower_name == "style" and re.search(r"url\s*\(", value, re.IGNORECASE):
                self.external_references.append(f"{lower_tag}[style]")

    def handle_endtag(self, tag: str) -> None:
        lower_tag = tag.lower()
        if lower_tag == "article":
            self._article = None
        if lower_tag == "nav" and self._nav_depth:
            self._nav_depth -= 1

    def handle_data(self, data: str) -> None:
        if self._article is None:
            return
        text = self._article["text"]
        if isinstance(text, list):
            text.append(data)


class ValidationError(Exception):
    pass


def validate_week_id(week: str) -> None:
    if not WEEK_RE.fullmatch(week):
        raise ValidationError("week must use YYYY-Www")
    try:
        date.fromisocalendar(int(week[:4]), int(week[6:]), 1)
    except ValueError as exc:
        raise ValidationError(f"invalid ISO week: {week}") from exc


def validate_html(path: Path, week: str, required_routes: list[str], staged: bool) -> list[str]:
    errors: list[str] = []
    warnings: list[str] = []
    validate_week_id(week)
    if not path.is_file():
        raise ValidationError(f"HTML file does not exist: {path}")
    if path.parent.name != week or (not staged and path.name != "index.html"):
        expected = f"<output_root>/{week}/{'<staged-file>' if staged else 'index.html'}"
        errors.append(f"file must be located at {expected}")
    try:
        source = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        raise ValidationError("HTML must be UTF-8")

    parser = NotesHTMLParser()
    try:
        parser.feed(source)
        parser.close()
    except Exception as exc:
        errors.append(f"HTML parsing failed: {exc}")

    if not parser.charset:
        errors.append("missing <meta charset=\"utf-8\">")
    if not parser.viewport:
        errors.append("missing viewport meta")
    if parser.main_weeks != [week]:
        errors.append(f"expected exactly one <main data-week=\"{week}\">")
    if not parser.topics:
        errors.append("at least one topic article is required")

    topic_ids: list[str] = []
    for topic in parser.topics:
        topic_id = topic.get("id")
        topic_slug = topic.get("topic")
        sections = topic.get("sections")
        if not isinstance(topic_id, str) or not topic_id:
            errors.append("every article needs a non-empty id")
            continue
        topic_ids.append(topic_id)
        if topic_slug != topic_id:
            errors.append(f"article {topic_id}: data-topic must equal id")
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", topic_id):
            errors.append(f"article {topic_id}: topic id must be kebab-case")
        if not isinstance(sections, set) or "outcome" not in sections:
            errors.append(f"article {topic_id}: missing section.outcome")
        if not isinstance(sections, set) or "rationale" not in sections:
            errors.append(f"article {topic_id}: missing section.rationale")
        text_parts = topic.get("text")
        topic_text = re.sub(r"\s+", " ", "".join(text_parts if isinstance(text_parts, list) else [])).strip()
        if len(topic_text) > 2500:
            errors.append(f"article {topic_id}: visible content exceeds 2500 characters")
        elif len(topic_text) > 1500:
            warnings.append(f"article {topic_id}: visible content exceeds 1500 characters")

    duplicate_counts = Counter(topic_ids)
    duplicates = sorted(topic for topic, count in duplicate_counts.items() if count > 1)
    if duplicates:
        errors.append(f"duplicate topic ids: {', '.join(duplicates)}")
    if len(parser.nav_targets) != len(set(parser.nav_targets)):
        errors.append("table of contents contains duplicate links")
    if set(parser.nav_targets) != set(topic_ids):
        errors.append("table of contents must link every topic exactly once")

    topics_by_id = {str(item.get("id")): item for item in parser.topics}
    for slug in required_routes:
        topic = topics_by_id.get(slug)
        sections = topic.get("sections") if topic else None
        if not isinstance(sections, set) or "route" not in sections:
            errors.append(f"article {slug}: optimization route is required")

    if parser.structure_errors:
        errors.extend(parser.structure_errors)
    if parser.forbidden:
        errors.append(f"forbidden HTML features: {', '.join(sorted(set(parser.forbidden)))}")
    css = "\n".join(re.findall(r"<style\b[^>]*>(.*?)</style>", source, re.IGNORECASE | re.DOTALL))
    if parser.external_references or re.search(r"(?:@import\b|url\s*\()", css, re.IGNORECASE):
        errors.append("external or active resources are not allowed")
    placeholders = sorted(set(PLACEHOLDER_RE.findall(source)))
    if placeholders:
        errors.append(f"unresolved placeholders: {', '.join(placeholders)}")

    visible = re.sub(r"<style\b[^>]*>.*?</style>", "", source, flags=re.IGNORECASE | re.DOTALL)
    visible = re.sub(r"<[^>]+>", " ", visible)
    visible = re.sub(r"\s+", " ", visible).strip()
    if len(visible) > 12000:
        errors.append("visible content exceeds 12000 characters; restructure and compress it")
    elif len(visible) > 8000:
        warnings.append("visible content exceeds 8000 characters; consider restructuring")

    mode = stat.S_IMODE(path.stat().st_mode)
    if mode & 0o077:
        errors.append(f"HTML permissions must not grant group/other access: {mode:04o}")
    parent_mode = stat.S_IMODE(path.parent.stat().st_mode)
    if parent_mode & 0o077:
        errors.append(f"week directory permissions must not grant group/other access: {parent_mode:04o}")

    for warning in warnings:
        print(f"WARN  {warning}")
    if errors:
        for error in errors:
            print(f"ERROR {error}")
        raise ValidationError(f"validation failed with {len(errors)} error(s)")
    return warnings


def command_config_get() -> int:
    try:
        data = load_config()
    except FileNotFoundError:
        print(f"UNCONFIGURED {config_path()}")
        return 3
    except ValueError as exc:
        print(f"ERROR {exc}", file=sys.stderr)
        return 2
    print(json.dumps(data, ensure_ascii=False))
    return 0


def command_config_set(raw: str) -> int:
    try:
        output_root = normalize_output_root(raw)
        path = save_config(output_root)
    except (OSError, ValueError) as exc:
        print(f"ERROR {exc}", file=sys.stderr)
        return 2
    print(json.dumps({"config_path": str(path), "output_root": str(output_root)}, ensure_ascii=False))
    return 0


def command_week(raw_date: str | None) -> int:
    try:
        config = load_config()
        day = parse_day(raw_date)
    except FileNotFoundError:
        print(f"UNCONFIGURED {config_path()}")
        return 3
    except ValueError as exc:
        print(f"ERROR {exc}", file=sys.stderr)
        return 2
    print(json.dumps(week_info(day, Path(config["output_root"])), ensure_ascii=False))
    return 0


def command_validate(raw_file: str, week: str, required_routes: list[str], staged: bool) -> int:
    try:
        validate_html(Path(raw_file).expanduser().resolve(), week, required_routes, staged)
    except (OSError, ValidationError) as exc:
        print(f"FAIL  {exc}", file=sys.stderr)
        return 1
    print(f"PASS  {raw_file} ({week})")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Manage configuration and validate weekly HTML notes")
    commands = parser.add_subparsers(dest="command", required=True)

    config = commands.add_parser("config")
    config_commands = config.add_subparsers(dest="config_command", required=True)
    config_commands.add_parser("get")
    config_set = config_commands.add_parser("set")
    config_set.add_argument("--output-root", required=True)

    week = commands.add_parser("week")
    week.add_argument("--date")

    validate = commands.add_parser("validate")
    validate.add_argument("--file", required=True)
    validate.add_argument("--week", required=True)
    validate.add_argument("--require-route", action="append", default=[])
    validate.add_argument("--staged", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.command == "config":
        if args.config_command == "get":
            return command_config_get()
        return command_config_set(args.output_root)
    if args.command == "week":
        return command_week(args.date)
    return command_validate(args.file, args.week, args.require_route, args.staged)


if __name__ == "__main__":
    sys.exit(main())
