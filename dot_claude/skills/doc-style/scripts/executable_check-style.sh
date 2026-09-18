#!/usr/bin/env bash
# Report constructions that the documentation rules in ~/.claude/CLAUDE.md exclude.
#
# Every hit is a candidate, not a verdict. Read each one and either rewrite it or keep it
# and state the reason. The script cannot judge context, and it cannot detect inconsistent
# terminology, duplicated explanations, or a description written as a requirement.
#
# YAML front matter, fenced code blocks and inline code spans are removed before matching,
# so identifiers and commands do not produce hits. Line numbers refer to the original file.
#
# The patterns assume Markdown. Running it on a source file also reports the file's own
# syntax, so on a source file judge the hits inside comments and ignore the rest.
#
#   check-style.sh docs/secrets.md README.md
#   check-style.sh --max-words 30 docs/architecture.md
#
# Exit status: 0 no candidates, 1 candidates reported, 2 usage error.
set -euo pipefail

err() { echo "$*" >&2; }

MAX_WORDS=25

usage() {
	err "usage: ${0##*/} [--max-words N] FILE..."
	exit 2
}

# Each entry is a label, a tab, and one case-insensitive extended regular expression.
PATTERNS=(
	"idiom	load.bearing|belt and braces|has teeth|not decoration|learned the hard way|that (is|was) the point|that's the point|blast radius|under the hood|out of the box|silver bullet|low.hanging fruit|rabbit hole|first.class citizen|heavy lifting|battle.tested|bulletproof|moving parts|at the end of the day|in the wild|boils down to|the trick is|rule of thumb|bells and whistles|footgun|gotcha|happy path|glue code|sanity check|magic|hand.wav|deep dive|baked in|table stakes|paper over|band.aid|move the needle|nail down|swiss army|apples to apples|the name of the game"
	"qualifier	\bjust\b|\bsimply\b|\bbasically\b|\bobviously\b|of course|\bactually\b|\bfairly\b|\bquite\b|pretty much|\ba bit\b|\bsomewhat\b|\bvery\b|\breally\b|more or less|\bnicely\b|\beasily\b|worth (doing|knowing|the)|\bideally\b|\bhopefully\b|\bprobably\b|\bmostly\b|\bvarious\b|in general|generally speaking|\bsimple enough\b"
	"filler	note that|worth noting|keep in mind|bear in mind|as you can see|\blet's\b|\blet us\b|we'll|we will now|you'll want|feel free|don't worry|remember that|please note|that said|to be honest|as mentioned (above|earlier)"
	"anthropomorphism	talks? to|knows about|is smart enough|magically|decides to|is happy|complains|cares about|is aware of|doesn't like|wants to know"
	"hype	\bleverage|\butilize|seamless|\brobust\b|\bpowerful\b|cutting.edge|state of the art|game.chang|best.in.class|\bblazing|effortless|rich set of|\belegant\b|\bdelightful\b|\bcomprehensive\b"
	"tone	!\s*$|^[^#|>].*\?\s*$|\bcool\b|\bawesome\b|\bnice!\b"
	"chain	—|[[:space:]]--[[:space:]]|;[[:space:]]"
)

# Blank out front matter and fenced code blocks, and reduce every inline code span to CODE,
# keeping one output line per input line so that grep -n reports the original line
# numbers and a code span still counts as one word.
strip_code() {
	awk '
		NR == 1 && /^---[[:space:]]*$/ { front = 1; print ""; next }
		front { if (/^---[[:space:]]*$/) front = 0; print ""; next }
		/^[[:space:]]*```/ { fence = !fence; print ""; next }
		fence { print ""; next }
		{ gsub(/`[^`]*`/, "CODE"); print }
	' "$1"
}

# Report sentences longer than MAX_WORDS. Paragraphs are accumulated because a sentence
# spans several wrapped lines. The reported line is where the paragraph starts.
long_sentences() {
	local file="$1"
	strip_code "$file" | awk -v file="$file" -v limit="$MAX_WORDS" '
		function flush(  tmp, parts, words, n, i, count) {
			if (buf ~ /^[[:space:]]*$/) { buf = ""; return }
			tmp = buf
			gsub(/[.!?:][[:space:]]+/, "&@@CUT@@", tmp)
			n = split(tmp, parts, "@@CUT@@")
			for (i = 1; i <= n; i++) {
				count = split(parts[i], words, /[[:space:]]+/)
				if (count > limit)
					printf "%s:%d: [length] %d-word sentence: %.56s...\n", file, start, count, parts[i]
			}
			buf = ""
		}
		/^[[:space:]]*$/ { flush(); next }
		/^[[:space:]]*[#|>]/ { flush(); next }
		{
			if (buf == "") start = NR
			buf = buf " " $0
		}
		END { flush() }
	'
}

scan_file() {
	local file="$1" stripped entry label regex hits line match snippet
	local -a src
	if [ ! -f "$file" ]; then
		err "no such file: $file"
		return 2
	fi
	mapfile -t src <"$file"
	stripped="$(strip_code "$file")"
	{
		for entry in "${PATTERNS[@]}"; do
			label="${entry%%	*}"
			regex="${entry#*	}"
			hits="$(printf '%s\n' "$stripped" | grep -n -i -o -E -- "$regex" || true)"
			[ -n "$hits" ] || continue
			while IFS=: read -r line match; do
				[ -n "$line" ] || continue
				snippet="${src[line - 1]}"
				snippet="${snippet#"${snippet%%[![:space:]]*}"}"
				printf '%s:%s: [%s] %s | %.52s\n' "$file" "$line" "$label" "$match" "$snippet"
			done <<<"$hits"
		done
		long_sentences "$file"
	} | sort -t: -k2,2n -s
}

FILES=()
while (($#)); do
	case "$1" in
	--max-words)
		MAX_WORDS="${2:-}"
		[[ "$MAX_WORDS" =~ ^[0-9]+$ ]] || usage
		shift 2
		;;
	-h | --help) usage ;;
	-*)
		err "unknown option: $1"
		usage
		;;
	*)
		FILES+=("$1")
		shift
		;;
	esac
done

((${#FILES[@]})) || usage

found=0
for file in "${FILES[@]}"; do
	output="$(scan_file "$file")"
	[ -n "$output" ] || continue
	printf '%s\n' "$output"
	found=1
done

if ((found)); then
	echo
	echo "Candidates reported. Rewrite each one, or keep it and state the reason."
	exit 1
fi
exit 0
