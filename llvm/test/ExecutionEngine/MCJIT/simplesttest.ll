; RUN: %lli -jit-kind=mcjit %s > /dev/null

define i32 @main() {
	ret i32 0
}

