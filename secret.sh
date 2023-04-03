#!/bin/bash

SECRET=$(cat secret.txt)
INDEX_FILES=$(find public/ -type f -iname "index.html")

for file in $INDEX_FILES; do
  echo "$SECRET" > "$file-new"
  cat "$file" >> "$file-new"
  rm "$file"
  mv "$file-new" "$file"
done
