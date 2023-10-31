#!/usr/bin/env python3

# ==============================================================================
# File Directory Comparison Tool
# ==============================================================================
# Description:
#   This script compares two directories to identify discrepancies in the files
#   contained within them. It achieves this by calculating and comparing the MD5
#   checksums of the files. If the MD5 checksums of two corresponding files do
#   not match, or if a file is missing in one of the directories, the script will
#   log this discrepancy.
#
# Usage:
#   python compare_dirs.py <dir1> <dir2>
#
# Parameters:
#   dir1: Path to the first directory
#   dir2: Path to the second directory
#
# Dependencies:
#   Python 3.6 or later
#   hashlib: For generating MD5 checksums
#   os: For file system operations
#   sys: For accessing command-line arguments
#   concurrent.futures: For parallelizing file comparisons
#   tqdm: For displaying a progress bar during execution
#
# Output:
#   A summary of mismatches between the two directories, including files that
#   do not exist in one of the directories, and files with mismatched MD5 checksums.
#
# Author:
#   https://github.com/nerrad567/bookish-funicular
#
# ==============================================================================
    

import hashlib
import os
import sys
import concurrent.futures
from tqdm import tqdm

def md5(file_path):
    hash_md5 = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

def compare_file(file_path_1, file_path_2):
    if not os.path.exists(file_path_2):
        return (file_path_1, file_path_2, "not_exist", "")

    checksum1 = md5(file_path_1)
    checksum2 = md5(file_path_2)

    if checksum1 != checksum2:
        return (file_path_1, file_path_2, checksum1, checksum2)
    else:
        return None

def process_file_pair(pair):
    return compare_file(*pair)

def compare_directories(dir1, dir2):
    mismatches = []
    file_pairs = []

    for root, _, files in os.walk(dir1):
        for file in files:
            file_path_1 = os.path.join(root, file)
            file_path_2 = os.path.join(root.replace(dir1, dir2), file)
            file_pairs.append((file_path_1, file_path_2))

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        results = list(tqdm(executor.map(process_file_pair, file_pairs), total=len(file_pairs)))

    for result in results:
        if result:
            mismatches.append(result)

    return mismatches

def main():
    if len(sys.argv) < 3:
        print("Usage: python compare_dirs.py <dir1> <dir2>")
        sys.exit(1)

    dir1 = sys.argv[1]
    dir2 = sys.argv[2]

    if not os.path.exists(dir1) or not os.path.exists(dir2):
        print("One or both directories do not exist.")
        sys.exit(1)

    mismatches = compare_directories(dir1, dir2)
    print("\nResults:")
    for file_path_1, file_path_2, checksum1, checksum2 in mismatches:
        if checksum2 == "":
            print(f"{file_path_2} does not exist.")
        else:
            print(f"Checksum mismatch for {file_path_1} and {file_path_2}")
            print(f"{file_path_1} checksum: {checksum1}")
            print(f"{file_path_2} checksum: {checksum2}")
            print()

if __name__ == "__main__":
    main()

