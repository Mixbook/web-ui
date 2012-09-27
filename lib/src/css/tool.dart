// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library csstool;

import 'dart:io';
import 'package:args/args.dart';
import 'package:web_components/src/template/cmd_options.dart';
import 'package:web_components/src/template/file_system.dart';
import 'package:web_components/src/template/file_system_vm.dart';
import 'package:web_components/src/template/source.dart';
import 'package:web_components/src/template/utils.dart';
import 'package:web_components/src/template/world.dart';
import 'css.dart';

FileSystem files;

/** Invokes [callback] and returns how long it took to execute in ms. */
num time(callback()) {
  final watch = new Stopwatch();
  watch.start();
  callback();
  watch.stop();
  return watch.elapsedInMs();
}

printStats(num elapsed, [String filename = '']) {
  print('Parsed ${GREEN_COLOR}${filename}${NO_COLOR} in ${elapsed} msec.');
}

/**
 * Run from the `tools/css` directory.
 *
 * Under google3 the location of the Dart VM is:
 *
 *   /home/<your name>/<P4 enlist dir>/google3/blaze-bin/third_party/dart_lang
 *
 * To use this tool your PATH must point to the location of the Dart VM:
 *
 *   export PATH=$PATH:/home/terry/src/google3/blaze-bin/third_party/dart_lang
 *
 * To run the tool CD to the location of the .scss file (e.g., lib/ui/view):
 *
 *   dart_bin ../tools/css/tool.dart --gen=view_lib_css view.scss
 *
 */
void main() {
  // tool.dart [options...] <css file>
  var args = commandOptions();
  ArgResults results = args.parse(new Options().arguments);

  if (results['help']) {
    print('Usage: [options...] <sourcefile> [outputPath]\n');
    print(args.getUsage());
    print("   sourcefile - scss innput file sourcefile");
    print("   outputPath - if specified directory to generate files; if not");
    print("                same directory as sourcefile");
    return;
  }

  String sourceFullFn = results.rest[0];
  String outputPath = results.rest.length > 1 ? results.rest[1] : null;

  // genName used for library name, base filename for .css and .dart files.
  String genName = results['gen'];

  initCssWorld(parseOptions(results, files));

  files = new VMFileSystem();

  Path srcPath = new Path(sourceFullFn);

  File fileSrc = new File.fromPath(srcPath);
  if (!fileSrc.existsSync()) {
    world.fatal("Source file missing - ${fileSrc.name}");
    return;
  }

  Directory srcDir = new Directory.fromPath(srcPath.directoryPath);

  // If outputDirectory not specified use the directory of the source file.
  if (outputPath == null || outputPath.isEmpty()) {
    outputPath = srcDir.path;
  }

  Directory outDirectory = new Directory(outputPath);
  if (!outDirectory.existsSync()) {
    outDirectory.createSync();
  }

  // CSS file to generate.
  String outputCssFn = '${outDirectory.path}$genName.css';

  // Dart file to generate.
  String outputDartFn = '${outDirectory.path}$genName.dart';

  String source = files.readAll(sourceFullFn);

  Stylesheet stylesheet;

  final elapsed = time(() {
    Parser parser = new Parser(
        new SourceFile(sourceFullFn, source), 0, files, srcDir.path);
    stylesheet = parser.parse();
  });

  printStats(elapsed, sourceFullFn);

  StringBuffer buff = new StringBuffer(
    '/* File generated by SCSS from source ${fileSrc.name}\n'
    ' * Do not edit.\n'
    ' */\n\n');
  buff.add(stylesheet.toString());

  files.writeString(outputCssFn, buff.toString());
  print("Generated file ${outputCssFn}");

  // Generate CSS.dart file.
  String genedClass = Generate.dartClass(stylesheet, fileSrc.name, genName);

  // Write Dart file.
  files.writeString(outputDartFn, genedClass);

  print("Generated file ${outputDartFn}");
}
