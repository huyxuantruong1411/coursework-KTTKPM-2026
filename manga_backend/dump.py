import os
import json

OUTPUT_FILE = "project_dump.txt"

# =========================
# FOLDER BỊ BỎ QUA
# =========================
IGNORE_DIRS = {
    "venv",
    ".venv",
    "__pycache__",
    "data",
    ".git",
    "flags",
    "pending-feature",
    "simulation",
    "debug",
    "node_modules",
    ".idea",
    ".vscode",
    "dist",
    "build"
}

# =========================
# FILE CỤ THỂ BỊ BỎ QUA
# =========================
IGNORE_FILES = {
    ".gitignore",
    ".gitattributes",
    OUTPUT_FILE.lower()
}

# =========================
# EXTENSION BỊ BỎ QUA
# =========================
IGNORE_EXTENSIONS = {
    ".log",
    ".csv",
    ".sqlite",
    ".db",
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".webp",
    ".mp4",
    ".mp3",
    ".zip",
    ".rar",
    ".7z",
    ".pdf",
    ".xlsx",
    ".xls",
    ".docx",
    ".pptx",
    ".exe",
    ".dll",
    ".bin",
    ".pyc"
}


def should_ignore_dir(dirname: str) -> bool:
    """
    Kiểm tra thư mục có cần bỏ qua không.
    """
    return dirname.lower() in IGNORE_DIRS


def should_ignore_file(filename: str) -> bool:
    """
    Kiểm tra file có cần bỏ qua không.
    """
    filename_lower = filename.lower()

    # Ignore exact filename
    if filename_lower in IGNORE_FILES:
        return True

    # Ignore extension
    _, ext = os.path.splitext(filename_lower)

    if ext in IGNORE_EXTENSIONS:
        return True

    return False


def build_tree_dict(root_dir: str) -> dict:
    """
    Trả về cây thư mục dưới dạng dict.
    """
    tree = {
        "name": os.path.basename(root_dir),
        "type": "directory",
        "children": []
    }

    try:
        with os.scandir(root_dir) as it:
            entries = sorted(it, key=lambda e: e.name.lower())

            for entry in entries:

                # =========================
                # DIRECTORY
                # =========================
                if entry.is_dir():

                    if should_ignore_dir(entry.name):
                        continue

                    tree["children"].append(
                        build_tree_dict(entry.path)
                    )

                # =========================
                # FILE
                # =========================
                elif entry.is_file():

                    if should_ignore_file(entry.name):
                        continue

                    tree["children"].append({
                        "name": entry.name,
                        "type": "file"
                    })

    except PermissionError:
        pass

    except Exception as e:
        tree["children"].append({
            "name": f"[ERROR] {str(e)}",
            "type": "error"
        })

    return tree


def build_tree_ascii(root_dir: str, prefix: str = "") -> str:
    """
    Tạo cây thư mục dạng ASCII.
    """
    entries = []

    try:
        with os.scandir(root_dir) as it:

            scanned = sorted(it, key=lambda e: e.name.lower())

            for entry in scanned:

                # =========================
                # DIRECTORY
                # =========================
                if entry.is_dir():

                    if should_ignore_dir(entry.name):
                        continue

                    entries.append(entry)

                # =========================
                # FILE
                # =========================
                elif entry.is_file():

                    if should_ignore_file(entry.name):
                        continue

                    entries.append(entry)

    except PermissionError:
        return ""

    except Exception:
        return ""

    lines = []

    for i, entry in enumerate(entries):

        connector = "└── " if i == len(entries) - 1 else "├── "

        if entry.is_dir():

            lines.append(
                prefix + connector + entry.name + "/"
            )

            extension = (
                "    "
                if i == len(entries) - 1
                else "│   "
            )

            subtree = build_tree_ascii(
                entry.path,
                prefix + extension
            )

            if subtree:
                lines.extend(subtree.splitlines())

        else:
            lines.append(
                prefix + connector + entry.name
            )

    return "\n".join(lines)


def dump_project(root_dir: str, output_file: str):

    with open(output_file, "w", encoding="utf-8") as out:

        # =========================
        # JSON TREE
        # =========================
        tree_dict = build_tree_dict(root_dir)

        out.write("=== Project Tree (JSON) ===\n")

        out.write(
            json.dumps(
                tree_dict,
                indent=2,
                ensure_ascii=False
            )
        )

        out.write("\n\n")

        # =========================
        # ASCII TREE
        # =========================
        out.write("=== Project Tree (ASCII) ===\n")

        out.write(root_dir + "/\n")

        out.write(
            build_tree_ascii(root_dir)
        )

        out.write("\n\n")

        # =========================
        # FILE CONTENTS
        # =========================
        for dirpath, dirnames, filenames in os.walk(root_dir):

            # Filter folders
            dirnames[:] = [
                d for d in dirnames
                if not should_ignore_dir(d)
            ]

            rel_path = os.path.relpath(
                dirpath,
                root_dir
            )

            if rel_path == ".":
                rel_path = ""

            out.write(
                f"\n=== Folder: {rel_path or root_dir} ===\n"
            )

            for filename in sorted(filenames):

                # Skip ignored files
                if should_ignore_file(filename):
                    continue

                file_path = os.path.join(
                    dirpath,
                    filename
                )

                out.write(
                    f"\n--- File: {file_path} ---\n"
                )

                try:
                    with open(
                        file_path,
                        "r",
                        encoding="utf-8"
                    ) as f:

                        out.write(f.read())

                except UnicodeDecodeError:
                    out.write(
                        "[Bỏ qua file binary / không đọc được UTF-8]\n"
                    )

                except Exception as e:
                    out.write(
                        f"[Lỗi đọc file: {e}]\n"
                    )


if __name__ == "__main__":

    current_dir = os.getcwd()

    dump_project(
        current_dir,
        OUTPUT_FILE
    )

    print(
        f"✅ Đã xuất project vào: {OUTPUT_FILE}"
    )