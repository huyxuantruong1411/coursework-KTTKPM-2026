import os
import json

OUTPUT_FILE = "flutter_project_dump.txt"

# Các thư mục thừa thãi, tự sinh hoặc chứa code platform không cần thiết cho việc đọc logic Flutter
IGNORED_DIRS = {
    ".git", 
    ".dart_tool", 
    "build", 
    ".idea", 
    ".vscode", 
    ".fvm",
    "android",  # Bỏ qua nếu chỉ cần code UI/Logic Dart
    "ios",      # Bỏ qua nếu chỉ cần code UI/Logic Dart
    "linux", 
    "macos", 
    "windows", 
    "web"       # Comment lại dòng này nếu bạn có viết custom code cho web (index.html)
}

# Các file tự sinh hoặc file lock quá dài
IGNORED_FILES = {
    "pubspec.lock",
    ".metadata",
    ".packages"
}

# Các đuôi file nhị phân, hình ảnh, font, media tránh lỗi khi đọc (UnicodeDecodeError) và làm rác file dump
IGNORED_EXTENSIONS = (
    ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico", ".webp",
    ".ttf", ".otf", ".woff", ".woff2",
    ".mp3", ".wav", ".mp4", ".avi",
    ".zip", ".tar", ".gz", ".rar", ".7z",
    ".sqlite", ".db",
    ".exe", ".dll", ".so", ".dylib", ".apk", ".aab", ".ipa",
    ".pem", ".p12", ".jks"
)

def should_ignore_dir(dirname: str) -> bool:
    return dirname.lower() in IGNORED_DIRS

def should_ignore_file(filename: str) -> bool:
    if filename.lower() in IGNORED_FILES:
        return True
    if filename.lower().endswith(IGNORED_EXTENSIONS):
        return True
    return False

def build_tree_dict(root_dir: str) -> dict:
    tree = {"name": os.path.basename(root_dir), "type": "directory", "children": []}

    if should_ignore_dir(os.path.basename(root_dir)):
        return tree

    try:
        with os.scandir(root_dir) as it:
            for entry in sorted(it, key=lambda e: e.name):
                if entry.is_dir():
                    if should_ignore_dir(entry.name):
                        continue
                    tree["children"].append(build_tree_dict(entry.path))
                elif entry.is_file():
                    if should_ignore_file(entry.name):
                        continue
                    tree["children"].append({"name": entry.name, "type": "file"})
    except PermissionError:
        pass
    return tree

def build_tree_ascii(root_dir: str, prefix: str = "") -> str:
    entries = []
    try:
        with os.scandir(root_dir) as it:
            for entry in sorted(it, key=lambda e: e.name):
                if entry.is_dir():
                    if should_ignore_dir(entry.name):
                        continue
                    entries.append(entry)
                elif entry.is_file():
                    if should_ignore_file(entry.name):
                        continue
                    entries.append(entry)
    except PermissionError:
        return ""

    lines = []
    for i, entry in enumerate(entries):
        connector = "└── " if i == len(entries) - 1 else "├── "
        if entry.is_dir():
            lines.append(prefix + connector + entry.name + "/")
            extension = "    " if i == len(entries) - 1 else "│   "
            lines.extend(build_tree_ascii(entry.path, prefix + extension).splitlines())
        else:
            lines.append(prefix + connector + entry.name)
    return "\n".join(lines)

def dump_project(root_dir: str, output_file: str):
    with open(output_file, "w", encoding="utf-8") as out:
        # Xuất cây thư mục dạng JSON
        tree_dict = build_tree_dict(root_dir)
        out.write("=== Project Tree (JSON) ===\n")
        out.write(json.dumps(tree_dict, indent=2, ensure_ascii=False))
        out.write("\n\n")

        # Xuất cây thư mục dạng ASCII
        out.write("=== Project Tree (ASCII) ===\n")
        out.write(os.path.basename(root_dir) + "/\n")
        out.write(build_tree_ascii(root_dir))
        out.write("\n\n")

        # Xuất nội dung tất cả file
        for dirpath, dirnames, filenames in os.walk(root_dir):
            # Lọc thư mục
            dirnames[:] = [d for d in dirnames if not should_ignore_dir(d)]

            rel_path = os.path.relpath(dirpath, root_dir)
            if rel_path == ".":
                rel_path = ""
            
            # Lọc file trong thư mục hiện tại
            valid_filenames = [f for f in filenames if not should_ignore_file(f)]
            
            if valid_filenames:
                out.write(f"\n{'='*40}\n")
                out.write(f"=== Folder: {rel_path or os.path.basename(root_dir)} ===\n")
                out.write(f"{'='*40}\n")

            for filename in valid_filenames:
                file_path = os.path.join(dirpath, filename)
                out.write(f"\n--- File: {os.path.join(rel_path, filename)} ---\n")
                out.write(f"```{'dart' if filename.endswith('.dart') else 'yaml' if filename.endswith('.yaml') else 'text'}\n")
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        out.write(f.read())
                except Exception as e:
                    out.write(f"[Lỗi đọc file: {e}]\n")
                out.write("\n```\n")

if __name__ == "__main__":
    current_dir = os.getcwd()
    dump_project(current_dir, OUTPUT_FILE)
    print(f"✅ Đã xuất toàn bộ file cần thiết của Flutter project vào {OUTPUT_FILE}")