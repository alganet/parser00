parser00_command_parse ()
{
	parser00_file="$1"
	cat "$parser00_file" | sed -n "$(parser00_filter)"
}

parser00_command_dump ()
{
	parser00_file="$1"

	parser00_command_parse "$parser00_file" >/dev/null || return 1

	# Register properties
	info () ( echo "package info: $*" )
	name () ( echo "package name: $*" )
	foo  () ( echo "package foo:  $*" )

	. "$parser00_file" && package || return 1
}

parser00_st ()
{
	callback="$1"
	when_expr="$2"
	repl_expr="$3"

	cat <<-SED
	/^	$when_expr	/ {
			s/^	$when_expr	\(.*\)/	\2\\
			$repl_expr/
			t $callback
	}
	SED
}

parser00_filter ()
{
	e_ws='[ 	]*'
	e_brco='{'
	e_brcc='}'
	e_open_entry="${e_ws}${e_brco}${e_ws}"
	e_close_entry="${e_ws}${e_brcc}${e_ws}"
	e_word="[a-zA-Z0-9_]*"
	e_literal="[a-zA-Z0-9_,.:/@)\(-][a-zA-Z0-9_,.:/@)\(-]*"
	e_entry="${e_ws}\(${e_word}\)${e_ws}()${e_ws}${e_brco}${e_ws}"
	e_forbidden="eval\|exec\|read"
	cat <<-SED
		:document_find
			$ exit

			# If starts with whitespace, print it
			/^${e_ws}$/ {
				p
				d
				N
				b document_find
			}

			# If starts with comment, print it
			/^${e_ws}#${e_ws}/ {
				p
				d
				N
				b document_find
			}

		# If starts with entry definition, begin entry
		/^${e_entry}$/ {
			b entry

		:entry_inside
			/^${e_entry}$/ b err_func
			# If starts with comment, print it

		:entry
			s/^${e_entry}$/\1 () {/
			p
			N

			# Removes previous line
			s/^.*\\
			//

			# Whitespace inside entry
			/^${e_ws}$/ b entry_inside

			# Open brackets
			/^${e_open_entry}$/ b entry_inside
			/^${e_close_entry}$/ b entry_end


			# If starts with comment, print it
			/^${e_ws}#${e_ws}/ {
				b entry_inside
			}

			# A Statement
			/^${e_word}/ b statement

			b document_find

		:entry_end
			p
			d
			N
			b document_find

		:statement
			# Trim line
			s/^${e_ws}\(.*\)${e_ws}$/\1/g

			# Puts a tab instead of each whitespace portion

			s/[ 	,][ 	,]*/	/g
			s/.*/	&	/

			# Ends if no tokens
			/^	\\
			/ b statement_end

			# Look for a key:
			$(parser00_st err_forbidden "\(${e_forbidden}\)"  "\1 ")
			$(parser00_st argument "\(${e_word}\)"  "\1 ")

			# Look for quotes
			b quote

		:argument
			# Ends if no tokens
			/^	\\
			/ b statement_end

			# Look for an argument
			$(parser00_st argument    "\(${e_word}\)" "\1 ")

			# Closing quote here means an error
			$(parser00_st err_closing "\(${e_literal}\"\)" "\1 ")

			b quote
		:quote
			# Closing quote here means an error
			$(parser00_st err_closing  "\(${e_literal}\"\)" "\1 ")

			# Opening a quote
			$(parser00_st quote_inside "\(\"${e_literal}\)" "\1 ")

			# Found a complete quoted identifier
			$(parser00_st argument     "\(\"${e_literal}\"\)" "\1 ")

		:quote_inside
			# End of string here means error
			/^	$/ b err_opening

			# Opening quote here means error
			$(parser00_st err_opening  "\(\"${e_literal}\"\)" "\1 ")

			# Found a plain e_literal, stay on the quotes
			$(parser00_st quote_inside "\(${e_literal}\)" "\1 ")

			# Found a closing quote, look for an argument
			$(parser00_st argument     "\(${e_literal}\"\)" "\1 ")


		# Everything shoul match, token error otherwise.
		b err_token

		:statement_end
			# Merges tokenized statement and look for more
			s/\\
			//g
			b entry_inside

		# ends entry
		}

		b err_command

		:err_closing
			a :
			a }
			a printf %s "Unexpected Closing Quotes"
			a exit 1
			b fail
		:err_command
			a printf %s "Unexpected Instruction"
			a exit 1
			b fail
		:err_func
			a :
			a }
			a printf %s "Unexpected Entry"
			a exit 1
			b fail
		:err_opening
			a :
			a }
			a printf %s "Unexpected Opening Quotes"
			a exit 1
			b fail
		:err_forbidden
			a :
			a }
			a printf %s "Invalid Property"
			a exit 1
			b fail
		:err_token
			a :
			a }
			a printf %s "Unexpected Token"
			a exit 1
			b fail
		:fail
			b fail_more

		:fail_more
			# Skips lines until the end of file
			$ b fail_message
			N
			b fail_more
		:fail_message
			# Delete and exit with error
			d
			q 1
		:exit
	SED
}
