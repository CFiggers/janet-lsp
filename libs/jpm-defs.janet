###
### Definitions related to [jpm](https://github.com/janet-lang/jpm),
### especially those used in `project.janet`.
###

(defn install-rule
  "Add install and uninstall rule for moving files from src into destdir."
  [src destdir])

(defn install-file-rule
  "Add install and uninstall rule for moving file from src into destdir."
  [src dest])

(defn uninstall
  "Uninstall bundle named name"
  [name])

(defn declare-native
  "Declare a native module. This is a shared library that can be loaded
  dynamically by a janet runtime. This also builds a static libary that
  can be used to bundle janet code and native into a single executable."
  [&keys opts])

(defn declare-source
  "Create Janet modules. This does not actually build the module(s),
  but registers them for packaging and installation. :source should be an
  array of files and directores to copy into JANET_MODPATH or JANET_PATH.
  :prefix can optionally be given to modify the destination path to be
  (string JANET_PATH prefix source)."
  [&keys {:source sources :prefix prefix}])

(defn declare-headers
  "Declare headers for a library installation. Installed headers can be used by other native
  libraries."
  [&keys {:headers headers :prefix prefix}])

(defn declare-bin
  "Declare a generic file to be installed as an executable."
  [&keys {:main main}])

(defn declare-executable
  "Declare a janet file to be the entry of a standalone executable program. The entry
  file is evaluated and a main function is looked for in the entry file. This function
  is marshalled into bytecode which is then embedded in a final executable for distribution.\n\n
  This executable can be installed as well to the --binpath given."
  [&keys {:install install :name name :entry entry :headers headers
          :cflags cflags :lflags lflags :deps deps :ldflags ldflags
          :no-compile no-compile :no-core no-core}])

(defn declare-binscript
  ``Declare a janet file to be installed as an executable script. Creates
  a shim on windows. If hardcode is true, will insert code into the script
  such that it will run correctly even when JANET_PATH is changed. if auto-shebang
  is truthy, will also automatically insert a correct shebang line.
  ``
  [&keys {:main main :hardcode-syspath hardcode :is-janet is-janet}])

(defn declare-archive
  "Build a janet archive. This is a file that bundles together many janet
  scripts into a janet image. This file can the be moved to any machine with
  a janet vm and the required dependencies and run there."
  [&keys opts])

(defn declare-manpage
  "Mark a manpage for installation"
  [page])

(defn run-tests
  "Run tests on a project in the current directory. The tests will
  be run in the environment dictated by (dyn :modpath)."
  [&opt root-directory])

(defn declare-project
  "Define your project metadata. This should
  be the first declaration in a project.janet file.
  Also sets up basic task targets like clean, build, test, etc."
  [&keys meta])