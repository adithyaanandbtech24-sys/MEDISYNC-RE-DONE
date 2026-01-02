#!/usr/bin/env python3
"""
Script to add all Swift files to Xcode project programmatically
"""

import os
import subprocess
import sys

def main():
    project_dir = "/Users/adithyaanand/Desktop/MEDISYNC_RE-DONE/MEDISYNC_RE-DONE"
    project_file = "/Users/adithyaanand/Desktop/MEDISYNC_RE-DONE/MEDISYNC_RE-DONE.xcodeproj"
    
    # Find all Swift files
    print("🔍 Finding all Swift files...")
    result = subprocess.run(
        ['find', project_dir, '-name', '*.swift', '-type', 'f'],
        capture_output=True,
        text=True
    )
    
    swift_files = [f.strip() for f in result.stdout.strip().split('\n') if f.strip()]
    print(f"✅ Found {len(swift_files)} Swift files")
    
    # Use xcodebuild to add files
    # This requires the xcodeproj Ruby gem
    print("\n📦 Checking for xcodeproj gem...")
    check_gem = subprocess.run(['gem', 'list', 'xcodeproj'], capture_output=True, text=True)
    
    if 'xcodeproj' not in check_gem.stdout:
        print("⚠️  xcodeproj gem not found. Installing...")
        subprocess.run(['sudo', 'gem', 'install', 'xcodeproj'], check=True)
    
    # Create Ruby script to add files
    ruby_script = f"""
require 'xcodeproj'

project_path = '{project_file}'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first
files_added = 0

{chr(10).join([f"file_ref = project.main_group.new_reference('{f}')" + chr(10) + "target.add_file_references([file_ref])" + chr(10) + "files_added += 1" for f in swift_files])}

project.save
puts "✅ Added #{{files_added}} files to Xcode project"
"""
    
    # Write Ruby script
    script_path = '/tmp/add_files_to_xcode.rb'
    with open(script_path, 'w') as f:
        f.write(ruby_script)
    
    print(f"\n🚀 Adding {len(swift_files)} files to Xcode project...")
    result = subprocess.run(['ruby', script_path], capture_output=True, text=True)
    
    if result.returncode == 0:
        print(result.stdout)
        print("\n✅ SUCCESS! All files added to Xcode project!")
        print("\n📱 Next steps:")
        print("   1. Open Xcode (already open)")
        print("   2. Press ⌘B to build")
        print("   3. All errors should be resolved!")
    else:
        print(f"❌ Error: {result.stderr}")
        return 1
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
