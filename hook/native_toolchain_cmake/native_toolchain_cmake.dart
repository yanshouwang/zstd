// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A library to invoke the native C compiler installed on the host machine.
library;

export 'src/builder/build_mode.dart';
export 'src/builder/cmake_builder.dart' show CMakeBuilder;
export 'src/builder/cbuilder.dart' show CBuilder;
export 'src/builder/clibrary.dart' show CLibrary;
export 'src/builder/clinker.dart' show CLinker;
export 'src/builder/language.dart' show Language;
export 'src/builder/linker_options.dart' show LinkerOptions;
export 'src/builder/optimization_level.dart';
export 'src/builder/output_type.dart' show OutputType;
export 'src/utils/env_from_bat.dart';
