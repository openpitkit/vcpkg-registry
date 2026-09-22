# The engine itself ships as a prebuilt shared library.
vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
# The engine library is code-signed and already carries an @rpath install
# name. Rewriting its load commands would break the signature, and arm64
# macOS refuses to load a library whose signature is broken.
set(VCPKG_FIXUP_MACHO_RPATH OFF)

vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO openpitkit/pit
  REF "v0.8.2"
  SHA512 c28927410d652b9f5c6292b8673cdae3ad5ff17f858efe18c747e8589f5487dae39e98ffecbd10c7b37a20d3a65f0ba084f8eea28e32a491e6ed69bac3f4be15)

# Select the engine for the target triplet and supply it to both the package
# build and the exported config.
if(VCPKG_TARGET_IS_WINDOWS)
  if(NOT VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    message(FATAL_ERROR
      "openpit: no prebuilt engine for windows-${VCPKG_TARGET_ARCHITECTURE}")
  endif()
  set(openpit_runtime_asset "openpit-ffi--windows-amd64-openpit_ffi.dll")
  set(openpit_runtime_sha512 "61d46c0801b674d36873691c28304a1fb9d03ae5f97092542097b8f6636e451ade290147a9c8314e90fb89099c86cd148c325321f22d7bc6c62e7554f8a09c15")
  set(openpit_runtime_file "openpit_ffi.dll")
  set(openpit_implib_asset "openpit-ffi--windows-amd64-openpit_ffi.dll.lib")
  set(openpit_implib_sha512 "348b876fb0378eb2fb785b40f6a134b3e6c171c4943c7bb4a738653cf0523e7b91ba393f30f7deb937227167368ba69ffa2728563dc64e70c29507169fc2c162")
  set(openpit_implib_file "openpit_ffi.lib")
elseif(VCPKG_TARGET_IS_OSX)
  set(openpit_runtime_file "libopenpit_ffi.dylib")
  if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(openpit_runtime_asset "openpit-ffi--darwin-arm64-libopenpit_ffi.dylib")
    set(openpit_runtime_sha512 "550f7e5a64d96f8d95c261ce6b689611757d3a76445e17741921485390b5e437a35e527c916e534db22fab8c48b5b8df088f0060ac9cf31854ed1d353045104f")
  elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(openpit_runtime_asset "openpit-ffi--darwin-amd64-libopenpit_ffi.dylib")
    set(openpit_runtime_sha512 "5afb52124cf144eff940c05c2857411b27eaddacdcb03c88deba2dc8b2e33d22583bd47c4e50c61996a987d00992028fc8ae6db94db601c4db3041fadbe23dfd")
  else()
    message(FATAL_ERROR
      "openpit: no prebuilt engine for osx-${VCPKG_TARGET_ARCHITECTURE}")
  endif()
elseif(VCPKG_TARGET_IS_LINUX)
  set(openpit_runtime_file "libopenpit_ffi.so")
  if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(openpit_runtime_asset "openpit-ffi--linux-arm64-libopenpit_ffi.so")
    set(openpit_runtime_sha512 "7b051b74f88db5eca7740b6c4fa474aaae88f31e987530e7c45acb4d3fd717d4b13222091de3a2d785e698dc7762ddc5a27a769ee3edec622fd245654d9820ff")
  elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(openpit_runtime_asset "openpit-ffi--linux-amd64-libopenpit_ffi.so")
    set(openpit_runtime_sha512 "0c2683678a53e12ade6dc8c694f1302be700f392783bdd7da29cf63ba6f0f6d7b8c3b3bab2540a9e973cc2b9831b13e3b18fb7e1782b579c9241d291607e8eb8")
  else()
    message(FATAL_ERROR
      "openpit: no prebuilt engine for linux-${VCPKG_TARGET_ARCHITECTURE}")
  endif()
else()
  message(FATAL_ERROR "openpit: unsupported target platform")
endif()

vcpkg_download_distfile(openpit_runtime_path
  URLS "https://github.com/openpitkit/pit/releases/download/v0.8.2/${openpit_runtime_asset}"
  FILENAME "openpit-${VERSION}-${openpit_runtime_asset}"
  SHA512 "${openpit_runtime_sha512}")

set(openpit_runtime_options
  "-DOPENPIT_RUNTIME_LIBRARY=${openpit_runtime_path}")
if(VCPKG_TARGET_IS_WINDOWS)
  vcpkg_download_distfile(openpit_implib_path
    URLS "https://github.com/openpitkit/pit/releases/download/v0.8.2/${openpit_implib_asset}"
    FILENAME "openpit-${VERSION}-${openpit_implib_asset}"
    SHA512 "${openpit_implib_sha512}")
  list(APPEND openpit_runtime_options
    "-DOPENPIT_RUNTIME_IMPORT_LIBRARY=${openpit_implib_path}")
endif()

# The C++ layer is a header-only wrapper around the C ABI, so one
# configuration of its CMake package covers every consumer.
block(SCOPE_FOR VARIABLES)
  set(VCPKG_BUILD_TYPE release)
  vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/bindings/cpp"
    OPTIONS
      ${openpit_runtime_options}
      "-DOPENPIT_CPP_BUILD_TESTS=OFF"
      "-DOPENPIT_PACKAGE_VERSION=0.8.2"
      "-DOPENPIT_RUNTIME_VERSION=0.8.2")
  vcpkg_cmake_install()
  vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/OpenPit)
endblock()

# The engine is released in one flavour. A triplet that builds both
# configurations gets the same binary under debug/ as well, so Debug consumers
# link and deploy it too.
set(openpit_install_prefixes "${CURRENT_PACKAGES_DIR}")
if(NOT VCPKG_BUILD_TYPE)
  list(APPEND openpit_install_prefixes "${CURRENT_PACKAGES_DIR}/debug")
endif()
if(VCPKG_TARGET_IS_WINDOWS)
  set(openpit_runtime_dir "bin")
else()
  set(openpit_runtime_dir "lib")
endif()
foreach(openpit_install_prefix IN LISTS openpit_install_prefixes)
  file(INSTALL "${openpit_runtime_path}"
    DESTINATION "${openpit_install_prefix}/${openpit_runtime_dir}"
    RENAME "${openpit_runtime_file}")
  if(VCPKG_TARGET_IS_WINDOWS)
    file(INSTALL "${openpit_implib_path}"
      DESTINATION "${openpit_install_prefix}/lib"
      RENAME "${openpit_implib_file}")
  endif()
endforeach()

# Point the exported config at the engine this port just installed. The
# resolver returns on the first branch when the path is set, so a consumer
# never reaches for a release asset. The config lives in share/${PORT}, hence
# two levels up.
set(openpit_config_file
  "${CURRENT_PACKAGES_DIR}/share/${PORT}/OpenPitConfig.cmake")
file(READ "${openpit_config_file}" openpit_config_contents)
string(FIND "${openpit_config_contents}" "openpit_resolve_runtime()"
  openpit_resolver_call)
if(openpit_resolver_call EQUAL -1)
  message(FATAL_ERROR
    "openpit: OpenPitConfig.cmake no longer calls openpit_resolve_runtime(), "
    "so the installed engine cannot be wired into the package config")
endif()
set(openpit_config_prelude
  "set(OPENPIT_RUNTIME_LIBRARY \"\${CMAKE_CURRENT_LIST_DIR}/../../${openpit_runtime_dir}/${openpit_runtime_file}\")")
if(VCPKG_TARGET_IS_WINDOWS)
  string(APPEND openpit_config_prelude
    "\nset(OPENPIT_RUNTIME_IMPORT_LIBRARY \"\${CMAKE_CURRENT_LIST_DIR}/../../lib/${openpit_implib_file}\")")
endif()
vcpkg_replace_string("${openpit_config_file}"
  "openpit_resolve_runtime()"
  "${openpit_config_prelude}\nopenpit_resolve_runtime()")

vcpkg_install_copyright(FILE_LIST
  "${SOURCE_PATH}/LICENSE"
  "${SOURCE_PATH}/THIRD-PARTY-LICENSES")
