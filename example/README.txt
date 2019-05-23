# Example

This example is a HTTP server, implemented as a server-side Dart
program, that produces HTML pages with client-side Dart scripts. In
production mode, it serves up pre-compiled JavaScript from a
directory. In debug mode, it serves dynamically compiled JavaScript
obtained from _webdev serve_.

## Running in production mode

1. Compile the client-side Dart scripts into JavaScript. In the top
   level directory (i.e. not in this _example_ directory), run `webdev
   build`. This will compile the assets from the "web" directory into
   the "build" directory.

2. Run the example HTTP server in production mode (where it serves the
   client-side scripts from the compiled files).

3. In a Web browser, load a page from the HTTP server (which is
   running on port 8000).

```sh
webdev build
dart example/example.dart
```

If needed, use the `--build` option to specify a different directory
for the compiled assets. Normally, the default ("../build" relative to
the server program file) will work.

## Running in debug mode

1. From the top level directory, run `webdev serve`. By default, it
listens on port 8080.

2. Run the example HTTP server in debug mode, by indicating where
"webdev serve" is running

3. In the Chrome Web browser, load a page from the HTTP server (which
is running on port 8000).

In one terminal:

```sh
webdev serve
```

In another terminal:

```sh
dart example.dart --debug http://localhost:8080
```

### Running "webdev serve" on a different port number

To run _webdev serve_ on a different port number:

```sh
webdev serve web:53322
```

And provide that port number to the HTTP server:

```sh
dart example.dart --debug http://localhost:53322
```

## Things to try

- If the Web page shows an error, examine the browser's JavaScript console.

- Edit `example/example.dart` to change the default logging level used.

