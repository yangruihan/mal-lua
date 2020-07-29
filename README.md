# MAL_lua

Make-A-Lisp with lua

Only use Lua standard lib without regex lib

Follow this [tutorial](https://github.com/kanaka/mal/blob/master/process/guide.md#step-a-metadata-self-hosting-and-interop)

## Run

```sh
lua main.lua

user> (println "Hello, Lisp")
Hello, Lisp
nil
```

or

```sh
lua main.lua xxx.lisp
```

## self-hosting

```sh
lua main.lua mal/stepA_mal.mal mal/stepA_mal.mal

mal-user>
```
