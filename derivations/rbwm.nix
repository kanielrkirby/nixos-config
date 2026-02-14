{ pkgs, ... }:

pkgs.writeShellScriptBin "rbwm" ''
  exec ${pkgs.python3}/bin/python3 << 'PYEOF'
import subprocess
import json
import sys
import os

def run(cmd, capture=True):
    if capture:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout.strip()
    else:
        subprocess.run(cmd, shell=True)
        return None

def dmenu(items, prompt="Select", allow_custom=False):
    """Show dmenu with items and return selection."""
    # Determine display environment
    wayland = os.environ.get("WAYLAND_DISPLAY")
    display = os.environ.get("DISPLAY")
    
    if wayland:
        menu_cmd = "bemenu -l 10 -i"
    elif display:
        menu_cmd = "dmenu -l 10 -i"
    else:
        print("No display server detected", file=sys.stderr)
        sys.exit(1)
    
    input_text = "\n".join(items) if items else ""
    result = subprocess.run(
        f"{menu_cmd} -p \"{prompt}\"",
        shell=True,
        input=input_text,
        capture_output=True,
        text=True
    )
    return result.stdout.strip() if result.returncode == 0 else None

def type_text(text):
    wayland = os.environ.get("WAYLAND_DISPLAY")
    if wayland:
        # Save original PRIMARY selection
        original = subprocess.run(["wl-paste", "--primary"], capture_output=True, text=True).stdout
        # Copy to PRIMARY and paste with Shift+Insert
        subprocess.run(["wl-copy", "--primary"], input=text, text=True)
        subprocess.run(["wtype", "-M", "shift", "-k", "Insert", "-m", "shift"])
        # Restore original PRIMARY
        subprocess.run(["wl-copy", "--primary"], input=original, text=True)
    else:
        # Try xclip first, fall back to xsel
        has_xclip = subprocess.run(["which", "xclip"], capture_output=True).returncode == 0
        if has_xclip:
            # Save both clipboards
            original_primary = subprocess.run(["xclip", "-selection", "primary", "-o"], capture_output=True, text=True).stdout
            original_clipboard = subprocess.run(["xclip", "-selection", "clipboard", "-o"], capture_output=True, text=True).stdout
            # Copy to BOTH primary and clipboard selections
            subprocess.run(["xclip", "-selection", "primary"], input=text, text=True)
            subprocess.run(["xclip", "-selection", "clipboard"], input=text, text=True)
            subprocess.run(["xdotool", "key", "shift+Insert"])
            # Restore both clipboards
            subprocess.run(["xclip", "-selection", "primary"], input=original_primary, text=True)
            subprocess.run(["xclip", "-selection", "clipboard"], input=original_clipboard, text=True)
        else:
            # Save both clipboards
            original_primary = subprocess.run(["xsel", "-p", "-o"], capture_output=True, text=True).stdout
            original_clipboard = subprocess.run(["xsel", "-b", "-o"], capture_output=True, text=True).stdout
            # Copy to BOTH primary and clipboard selections
            subprocess.run(["xsel", "-p", "-i"], input=text, text=True)
            subprocess.run(["xsel", "-b", "-i"], input=text, text=True)
            subprocess.run(["xdotool", "key", "shift+Insert"])
            # Restore both clipboards
            subprocess.run(["xsel", "-p", "-i"], input=original_primary, text=True)
            subprocess.run(["xsel", "-b", "-i"], input=original_clipboard, text=True)

def press_tab():
    """Press Tab key."""
    wayland = os.environ.get("WAYLAND_DISPLAY")
    
    if wayland:
        subprocess.run(["wtype", "-k", "Tab"])
    else:
        subprocess.run(["xdotool", "key", "Tab"])

def press_enter():
    """Press Enter key."""
    wayland = os.environ.get("WAYLAND_DISPLAY")
    
    if wayland:
        subprocess.run(["wtype", "-k", "Return"])
    else:
        subprocess.run(["xdotool", "key", "Return"])

def get_entries():
    output = run("rbw list --raw")
    all_entries = json.loads(output) if output else []
    entries = []
    for item in all_entries:
        name = item.get("name", "")
        user = item.get("user", "")
        folder = item.get("folder", "")
        entry_type = item.get("type", "")
        display = name
        if user:
            display += f" ({user})"
        if folder:
            display += f" [{folder}]"
        entries.append({"display": display, "name": name, "user": user, "folder": folder, "type": entry_type})
    return entries

def get_entry_data(name):
    output = run(f"rbw get --raw \"{name}\"")
    if not output:
        return {}
    try:
        return json.loads(output)
    except:
        return {}

def main():
    # Check if unlocked
    is_unlocked = subprocess.run(["rbw", "unlocked"], capture_output=True).returncode == 0
    lock_option = "[Lock]" if is_unlocked else "[Unlock]"
    
    entries = get_entries()
    # Filter out notes from main list (they have their own [Notes] option)
    login_entries = [e for e in entries if e.get("type") != "Note"]
    entry_displays = ["[Details]", "[Notes]", "[Sync]", "[Add]", "[Edit]", "[Remove]", lock_option] + [e["display"] for e in login_entries]
    
    choice = dmenu(entry_displays, "Bitwarden")
    if not choice:
        return
    
    # Handle special options
    if choice == "[Details]":
        entry_choice = dmenu([e["display"] for e in login_entries], "Select entry")
        if not entry_choice:
            return
        entry_name = next((e["name"] for e in login_entries if e["display"] == entry_choice), None)
        if not entry_name:
            return
        data = get_entry_data(entry_name)
        entry_data = data.get("data", {})
        if not entry_data:
            return
        
        # Build field menu from ALL fields in data
        fields = []
        field_values = {}
        for key, value in entry_data.items():
            if value is None or value == "" or value == []:
                continue
            if key == "password":
                fields.append("password")
                field_values["password"] = value
            elif key == "totp":
                totp = run(f"rbw code \"{entry_name}\" 2>/dev/null")
                if totp:
                    fields.append("totp")
                    field_values["totp"] = totp
            elif key == "uris" and isinstance(value, list) and len(value) > 0:
                for i, uri_obj in enumerate(value):
                    uri_val = uri_obj.get("uri", "")
                    if uri_val:
                        field_label = f"uri{i}" if i > 0 else "uri"
                        fields.append(f"{field_label}: {uri_val}")
                        field_values[field_label] = uri_val
            elif isinstance(value, str):
                if key == "notes":
                    preview = value.split("\n")[0][:50]
                    fields.append(f"{key}: {preview}...")
                else:
                    fields.append(f"{key}: {value}")
                field_values[key] = value
            elif isinstance(value, (int, float, bool)):
                fields.append(f"{key}: {value}")
                field_values[key] = str(value)
        
        if not fields:
            return
        
        field_choice = dmenu(fields, "Select field")
        if not field_choice:
            return
        
        field_name = field_choice.split(":")[0].strip()
        value = field_values.get(field_name, "")
        if value:
            type_text(value)
    elif choice == "[Sync]":
        run("rbw sync", capture=False)
        return
    elif choice == "[Add]":
        # Interactive add - build entry field by field
        new_entry = {"name": "", "username": "", "password": "", "uri": "", "folder": "", "notes": ""}
        while True:
            fields = []
            for k, v in new_entry.items():
                if k == "password" and v:
                    fields.append(f"{k}: {'*' * len(v)}")
                else:
                    fields.append(f"{k}: {v if v else '(empty)'}")
            fields.append("[Save]")
            fields.append("[Discard]")
            field_choice = dmenu(fields, "Add Entry - Select field to edit")
            if not field_choice or field_choice == "[Discard]":
                return
            if field_choice == "[Save]":
                if not new_entry["name"]:
                    continue  # Need at least a name
                # rbw add only supports name, username, and password via stdin
                # Format: password\nnotes
                add_input = new_entry["password"]
                if new_entry["notes"]:
                    add_input += "\n" + new_entry["notes"]
                cmd = ["rbw", "add", new_entry["name"]]
                if new_entry["username"]:
                    cmd.append(new_entry["username"])
                if new_entry["folder"]:
                    cmd.extend(["--folder", new_entry["folder"]])
                if new_entry["uri"]:
                    cmd.extend(["--uri", new_entry["uri"]])
                subprocess.run(cmd, input=add_input, text=True)
                return
            field_name = field_choice.split(":")[0].strip()
            value = dmenu([], f"Enter {field_name}", allow_custom=True)
            if value is not None:
                new_entry[field_name] = value
        return
    elif choice == "[Edit]":
        entry_choice = dmenu([e["display"] for e in login_entries], "Select entry to edit")
        if not entry_choice:
            return
        entry_name = next((e["name"] for e in login_entries if e["display"] == entry_choice), None)
        if not entry_name:
            return
        # Get current data
        data = get_entry_data(entry_name)
        entry_data = data.get("data", {}) or {}
        edit_fields = {
            "username": entry_data.get("username") or "",
            "password": entry_data.get("password") or "",
            "uri": entry_data.get("uris", [{}])[0].get("uri", "") if entry_data.get("uris") else "",
            "folder": data.get("folder") or "",
            "notes": data.get("notes") or ""
        }
        while True:
            fields = []
            for k, v in edit_fields.items():
                if k == "password" and v:
                    fields.append(f"{k}: {'*' * len(v)}")
                else:
                    fields.append(f"{k}: {v if v else '(empty)'}")
            fields.append("[Save]")
            fields.append("[Discard]")
            field_choice = dmenu(fields, f"Edit {entry_name} - Select field")
            if not field_choice or field_choice == "[Discard]":
                return
            if field_choice == "[Save]":
                # rbw doesn't support editing individual fields, so we need to remove and recreate
                subprocess.run(["rbw", "remove", entry_name])
                # Recreate with new values
                add_input = edit_fields["password"]
                if edit_fields["notes"]:
                    add_input += "\n" + edit_fields["notes"]
                cmd = ["rbw", "add", entry_name]
                if edit_fields["username"]:
                    cmd.append(edit_fields["username"])
                if edit_fields["folder"]:
                    cmd.extend(["--folder", edit_fields["folder"]])
                if edit_fields["uri"]:
                    cmd.extend(["--uri", edit_fields["uri"]])
                subprocess.run(cmd, input=add_input, text=True)
                return
            field_name = field_choice.split(":")[0].strip()
            current = edit_fields.get(field_name, "")
            value = dmenu([], f"Enter {field_name} (current: {current[:30]}...)" if len(current) > 30 else f"Enter {field_name} (current: {current})", allow_custom=True)
            if value is not None and value != "":
                edit_fields[field_name] = value
        return
    elif choice == "[Remove]":
        entry_choice = dmenu([e["display"] for e in login_entries], "Select entry to remove")
        if not entry_choice:
            return
        entry_name = next((e["name"] for e in login_entries if e["display"] == entry_choice), None)
        if not entry_name:
            return
        run(f"rbw remove \"{entry_name}\"", capture=False)
        return
    elif choice == "[Lock]":
        run("rbw lock", capture=False)
        return
    elif choice == "[Unlock]":
        run("st -e rbw unlock", capture=False)
        return
    elif choice == "[Notes]":
        note_entries = [e["display"] for e in entries if e.get("type") == "Note"]
        if not note_entries:
            return
        entry_choice = dmenu(note_entries, "Select note")
        if not entry_choice:
            return
        entry_name = next((e["name"] for e in entries if e["display"] == entry_choice), None)
        if not entry_name:
            return
        data = get_entry_data(entry_name)
        notes = data.get("notes", "")
        if notes:
            type_text(notes)
    else:
        entry_name = next((e["name"] for e in login_entries if e["display"] == choice), None)
        if not entry_name:
            return
        data = get_entry_data(entry_name)
        entry_data = data.get("data", {}) or {}
        username = entry_data.get("username") or ""
        password = entry_data.get("password") or ""
        
        if username and password:
            type_text(username)
            press_tab()
            type_text(password)
            press_enter()
        elif username:
            type_text(username)
        elif password:
            type_text(password)
        else:
            # Find first non-empty field in data
            for key, value in entry_data.items():
                if value and isinstance(value, str) and key not in ["totp"]:
                    type_text(value)
                    return
            # Try notes from top level
            notes = data.get("notes") or ""
            if notes:
                type_text(notes)

if __name__ == "__main__":
    main()
PYEOF
''
