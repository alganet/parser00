```sh
$ # Show all examples
$ find example_*

$ # Run the parser
$ ./parser00 parse example_fail1.sh
package () {
    info "Foo" 
:
}
printf %s "Unexpected Token"
exit 1

$ # Run the dumper
$ ./parser00 dump example_success.sh
package info: Foo
package info: bar
```