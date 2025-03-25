#!/bin/bash

# Convert snake_case to CamelCase for class names
snake_to_camel() {
  echo "$1" | awk -F '_' '{for(i=1;i<=NF;i++) {$i=toupper(substr($i,1,1)) substr($i,2)}} 1' OFS=''
}

mkdir -p sig/mobilis
find lib/mobilis -name '*.rb' | while read -r file; do
  rbs_file="sig/$(echo $file | sed 's|lib/||' | sed 's|.rb$|.rbs|')"
  rbs_dir=$(dirname "$rbs_file")
  mkdir -p "$rbs_dir"
  if [ ! -f "$rbs_file" ]; then
    relative_path=$(echo "$file" | sed 's|lib/||' | sed 's|.rb$||')
    IFS='/' read -ra parts <<< "$relative_path"
    class_name="Mobilis"
    for part in "${parts[@]}"; do
      class_name+="::$(snake_to_camel "$part")"
    done

    echo "class $class_name" > "$rbs_file"

    # Add attr_readers
    attr_lines=$(grep -E '^[[:space:]]*attr_reader' "$file" | sed 's/attr_reader //' | tr -d ':,' | tr ' ' '\n')
    for attr in $attr_lines; do
      echo "  attr_reader $attr: untyped" >> "$rbs_file"
    done

    # Infer initialize params as untyped
    init_line=$(grep -E 'def initialize' "$file" | head -n 1)
    if [[ ! -z "$init_line" ]]; then
      init_args=$(echo "$init_line" | sed -E 's/.*initialize\((.*)\).*/\1/' | tr -d ' ')
      if [[ "$init_args" == "" ]]; then
        echo "  def initialize: () -> void" >> "$rbs_file"
      else
        typed_args=$(echo "$init_args" | tr ',' '\n' | sed -E 's/.*([a-zA-Z_][a-zA-Z0-9_]*)(=.*)?/\1: untyped/' | paste -sd, -)
        echo "  def initialize: ($typed_args) -> void" >> "$rbs_file"
      fi
    else
      echo "  def initialize: () -> void" >> "$rbs_file"
    fi

    echo "end" >> "$rbs_file"

    echo "Generated stub for $class_name with fallback inference"
  fi
done
