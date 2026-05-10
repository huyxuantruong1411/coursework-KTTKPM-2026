import os
import json
import hashlib
from datetime import datetime

# =========================================================
# CONFIG
# =========================================================

# Chọn:
# "txt" hoặc "md"
OUTPUT_FORMAT = "md"

OUTPUT_FILE = f"project_dump.{OUTPUT_FORMAT}"

MAX_FILE_SIZE_MB = 2

MAX_FILE_SIZE = MAX_FILE_SIZE_MB * 1024 * 1024

# =========================================================
# IGNORE DIRECTORIES
# =========================================================

IGNORE_DIRS = {
    "node_modules",
    ".next",
    "dist",
    "build",
    ".git",
    ".idea",
    ".vscode",
    "__pycache__",
    ".pytest_cache",
    ".turbo",
    ".vercel",
    ".cache",
    "coverage",
    "logs",
    "tmp",
    "temp",
    "vendor",
    "bin",
    "obj",
    "out"
}

# =========================================================
# IGNORE FILES
# =========================================================

IGNORE_FILES = {
    OUTPUT_FILE.lower(),
    ".ds_store",
    "thumbs.db",
    "package-lock.json",
    "pnpm-lock.yaml",
    "yarn.lock"
}

# =========================================================
# IGNORE EXTENSIONS
# =========================================================

IGNORE_EXTENSIONS = {
    # Images
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".webp",
    ".svg",
    ".ico",

    # Video
    ".mp4",
    ".mov",
    ".avi",
    ".mkv",

    # Audio
    ".mp3",
    ".wav",

    # Archives
    ".zip",
    ".rar",
    ".7z",
    ".tar",
    ".gz",

    # Binary
    ".exe",
    ".dll",
    ".so",
    ".bin",
    ".pyc",
    ".class",

    # Documents
    ".pdf",
    ".docx",
    ".pptx",
    ".xlsx",

    # Database
    ".db",
    ".sqlite",
    ".sqlite3",

    # Logs
    ".log"
}

# =========================================================
# ALLOWED SOURCE CODE EXTENSIONS
# =========================================================

ALLOWED_CODE_EXTENSIONS = {
    ".ts",
    ".tsx",
    ".js",
    ".jsx",

    ".json",

    ".css",
    ".scss",
    ".sass",
    ".less",

    ".html",

    ".md",

    ".py",

    ".yml",
    ".yaml",

    ".env",

    ".sql",

    ".sh",
    ".bash",

    ".toml",

    ".graphql",

    ".prisma"
}

# =========================================================
# IMPORTANT FILES
# =========================================================

IMPORTANT_FILES = {
    "package.json",
    "tsconfig.json",
    "next.config.js",
    "next.config.ts",
    "vite.config.ts",
    "vite.config.js",
    "tailwind.config.js",
    "tailwind.config.ts",
    ".env.example",
    ".env",
    "docker-compose.yml",
    "Dockerfile",
    "README.md"
}

# =========================================================
# HELPERS
# =========================================================

def should_ignore_dir(dirname: str) -> bool:
    return dirname.lower() in IGNORE_DIRS


def should_ignore_file(filename: str) -> bool:

    lower = filename.lower()

    # Ignore exact filename
    if lower in IGNORE_FILES:
        return True

    name, ext = os.path.splitext(lower)

    # Ignore binary/media extensions
    if ext in IGNORE_EXTENSIONS:
        return True

    # Nếu file KHÔNG nằm trong allowed extensions
    # thì bỏ qua
    if ext not in ALLOWED_CODE_EXTENSIONS:

        # Một số file đặc biệt không có extension
        special_files = {
            "dockerfile",
            ".env",
            ".env.local",
            ".env.example",
            ".gitignore",
            ".npmrc",
            ".prettierrc",
            ".eslintrc"
        }

        if lower not in special_files:
            return True

    return False


def get_file_hash(filepath: str) -> str:
    """
    SHA256 hash file.
    """

    sha256 = hashlib.sha256()

    try:

        with open(filepath, "rb") as f:

            for chunk in iter(lambda: f.read(8192), b""):
                sha256.update(chunk)

        return sha256.hexdigest()

    except Exception:
        return "ERROR"


def format_size(size_bytes: int) -> str:

    for unit in ["B", "KB", "MB", "GB"]:

        if size_bytes < 1024:
            return f"{size_bytes:.2f} {unit}"

        size_bytes /= 1024

    return f"{size_bytes:.2f} TB"


def write_section(out, title: str):

    if OUTPUT_FORMAT == "md":

        out.write(f"\n# {title}\n\n")

    else:

        out.write(
            f"\n{'=' * 80}\n"
        )

        out.write(title + "\n")

        out.write(
            f"{'=' * 80}\n\n"
        )


def get_markdown_language(filename: str) -> str:

    _, ext = os.path.splitext(filename)

    ext = ext.lower()

    lang_map = {
        ".py": "python",
        ".ts": "typescript",
        ".tsx": "tsx",
        ".js": "javascript",
        ".jsx": "jsx",
        ".json": "json",
        ".css": "css",
        ".scss": "scss",
        ".sass": "scss",
        ".less": "css",
        ".md": "markdown",
        ".yml": "yaml",
        ".yaml": "yaml",
        ".html": "html",
        ".sql": "sql",
        ".graphql": "graphql",
        ".sh": "bash",
        ".toml": "toml"
    }

    return lang_map.get(ext, "")

# =========================================================
# BUILD ASCII TREE
# =========================================================

def build_ascii_tree(root_dir: str, prefix: str = "") -> str:

    entries = []

    try:

        with os.scandir(root_dir) as scan:

            for entry in sorted(scan, key=lambda e: e.name.lower()):

                if entry.is_dir():

                    if should_ignore_dir(entry.name):
                        continue

                    entries.append(entry)

                elif entry.is_file():

                    if should_ignore_file(entry.name):
                        continue

                    entries.append(entry)

    except Exception:
        return ""

    lines = []

    for index, entry in enumerate(entries):

        connector = "└── " if index == len(entries) - 1 else "├── "

        name = entry.name

        if entry.is_dir():
            name += "/"

        lines.append(prefix + connector + name)

        if entry.is_dir():

            extension = (
                "    "
                if index == len(entries) - 1
                else "│   "
            )

            subtree = build_ascii_tree(
                entry.path,
                prefix + extension
            )

            if subtree:
                lines.extend(subtree.splitlines())

    return "\n".join(lines)

# =========================================================
# PROJECT STATS
# =========================================================

def collect_stats(root_dir: str):

    total_files = 0
    total_dirs = 0
    total_size = 0

    extension_map = {}

    for dirpath, dirnames, filenames in os.walk(root_dir):

        dirnames[:] = [
            d for d in dirnames
            if not should_ignore_dir(d)
        ]

        total_dirs += len(dirnames)

        for filename in filenames:

            if should_ignore_file(filename):
                continue

            total_files += 1

            filepath = os.path.join(dirpath, filename)

            try:

                size = os.path.getsize(filepath)

                total_size += size

                _, ext = os.path.splitext(filename)

                ext = ext.lower()

                extension_map[ext] = (
                    extension_map.get(ext, 0) + 1
                )

            except Exception:
                pass

    return {
        "total_files": total_files,
        "total_dirs": total_dirs,
        "total_size": format_size(total_size),
        "extensions": dict(
            sorted(
                extension_map.items(),
                key=lambda x: x[1],
                reverse=True
            )
        )
    }

# =========================================================
# READ FILE CONTENT
# =========================================================

def read_file_content(filepath: str) -> str:

    try:

        size = os.path.getsize(filepath)

        if size > MAX_FILE_SIZE:

            return (
                f"[SKIPPED: File too large "
                f"({format_size(size)})]"
            )

        with open(
            filepath,
            "r",
            encoding="utf-8"
        ) as f:

            return f.read()

    except UnicodeDecodeError:
        return "[SKIPPED: Binary or non UTF-8 file]"

    except Exception as e:
        return f"[ERROR READING FILE: {str(e)}]"

# =========================================================
# WRITE FILE CONTENT
# =========================================================

def write_file_content(out, filename: str, content: str):

    if OUTPUT_FORMAT == "md":

        lang = get_markdown_language(filename)

        out.write(f"```{lang}\n")

        out.write(content)

        out.write("\n```\n")

    else:

        out.write(content)

# =========================================================
# DUMP PROJECT
# =========================================================

def dump_project(root_dir: str):

    stats = collect_stats(root_dir)

    with open(
        OUTPUT_FILE,
        "w",
        encoding="utf-8"
    ) as out:

        # =================================================
        # HEADER
        # =================================================

        write_section(out, "PROJECT DUMP")

        out.write(f"Generated: {datetime.now()}\n")
        out.write(f"Root: {root_dir}\n\n")

        # =================================================
        # STATS
        # =================================================

        write_section(out, "PROJECT STATS")

        if OUTPUT_FORMAT == "md":

            out.write("```json\n")

            out.write(json.dumps(
                stats,
                indent=2,
                ensure_ascii=False
            ))

            out.write("\n```\n")

        else:

            out.write(json.dumps(
                stats,
                indent=2,
                ensure_ascii=False
            ))

        out.write("\n\n")

        # =================================================
        # TREE
        # =================================================

        write_section(out, "PROJECT TREE")

        if OUTPUT_FORMAT == "md":

            out.write("```txt\n")

            out.write(root_dir + "\n")

            out.write(
                build_ascii_tree(root_dir)
            )

            out.write("\n```\n")

        else:

            out.write(root_dir + "\n")

            out.write(
                build_ascii_tree(root_dir)
            )

        out.write("\n\n")

        # =================================================
        # IMPORTANT FILES
        # =================================================

        write_section(out, "IMPORTANT FILES")

        for dirpath, dirnames, filenames in os.walk(root_dir):

            dirnames[:] = [
                d for d in dirnames
                if not should_ignore_dir(d)
            ]

            for filename in filenames:

                if filename not in IMPORTANT_FILES:
                    continue

                filepath = os.path.join(
                    dirpath,
                    filename
                )

                relative_path = os.path.relpath(
                    filepath,
                    root_dir
                )

                content = read_file_content(filepath)

                if OUTPUT_FORMAT == "md":

                    out.write(
                        f"\n## FILE: {relative_path}\n\n"
                    )

                else:

                    out.write(
                        f"\n{'-' * 80}\n"
                    )

                    out.write(
                        f"FILE: {relative_path}\n"
                    )

                    out.write(
                        f"{'-' * 80}\n"
                    )

                write_file_content(
                    out,
                    filename,
                    content
                )

                out.write("\n")

        # =================================================
        # SOURCE FILES
        # =================================================

        write_section(out, "SOURCE FILES")

        for dirpath, dirnames, filenames in os.walk(root_dir):

            dirnames[:] = [
                d for d in dirnames
                if not should_ignore_dir(d)
            ]

            for filename in sorted(filenames):

                if should_ignore_file(filename):
                    continue

                filepath = os.path.join(
                    dirpath,
                    filename
                )

                try:
                    size = os.path.getsize(filepath)

                except Exception:
                    size = 0

                relative_path = os.path.relpath(
                    filepath,
                    root_dir
                )

                if OUTPUT_FORMAT == "md":

                    out.write(
                        f"\n# FILE: {relative_path}\n\n"
                    )

                    out.write(
                        f"- SIZE: {format_size(size)}\n"
                    )

                    out.write(
                        f"- SHA256: "
                        f"{get_file_hash(filepath)}\n\n"
                    )

                else:

                    out.write(
                        f"\n{'=' * 80}\n"
                    )

                    out.write(
                        f"FILE: {relative_path}\n"
                    )

                    out.write(
                        f"SIZE: {format_size(size)}\n"
                    )

                    out.write(
                        f"SHA256: "
                        f"{get_file_hash(filepath)}\n"
                    )

                    out.write(
                        f"{'=' * 80}\n\n"
                    )

                content = read_file_content(filepath)

                write_file_content(
                    out,
                    filename,
                    content
                )

                out.write("\n\n")

    print(f"\n✅ Dump completed: {OUTPUT_FILE}")

# =========================================================
# MAIN
# =========================================================

if __name__ == "__main__":

    current_dir = os.getcwd()

    dump_project(current_dir)