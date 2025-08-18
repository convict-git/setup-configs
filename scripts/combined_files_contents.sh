#!/bin/bash

# Function to process a single file
process_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local relpath
        relpath=$(realpath --relative-to="." "$file")
        echo "// ${relpath}"
        cat "$file"
        echo "// --------------------------------------------------------------------------------"
        echo    # print a newline between files
    fi
}

# Use a temporary buffer to collect output
output="Context: You are an expert-level software engineer. You will be given one or more code files for analysis and modification. Your task is to provide precise, grounded insights only based on the content of the provided code. Strict Instructions: Do not hallucinate. If something is not explicitly defined or inferable from the code and context, say so clearly and ask for clarification. Stick strictly to what is in the provided files. Do not guess missing behavior, intent, or architecture. Before making changes, clearly state your understanding of the current behavior and justify why the proposed change makes sense. All reasoning must be precise and deliberate, even if it seems obvious. Avoid hand-wavy explanations. If there are multiple ways to implement a change, list pros/cons for each with detailed reasoning and recommend the most suitable option. If the code references external dependencies (libraries, APIs), mention it only if they are used in the file or explicitly imported. Otherwise, ask for confirmation before making assumptions. Clarification protocol: If anything is ambiguous, pause and ask for additional input or files, rather than assuming. If behavior depends on external context not included, state clearly: \"Cannot determine without additional context.\" Output style: Use structured reasoning: (1) state assumptions, (2) describe current behavior, (3) explain your interpretation, (4) present any planned changes or questions. If asked a question, return the answer along with your reasoning path, not just the conclusion.  \
//--------------------------------------------------------------------------------"

# Recursively process all inputs
for input in "$@"; do
    if [[ -f "$input" ]]; then
        output+=$(process_file "$input")
    elif [[ -d "$input" ]]; then
        while IFS= read -r -d '' file; do
            output+=$(process_file "$file")
        done < <(find "$input" -type f -print0 | sort -z)
    else
        echo "Warning: '$input' is not a file or directory" >&2
    fi
done

# Output to clipboard
printf "%s" "$output" | pbcopy
