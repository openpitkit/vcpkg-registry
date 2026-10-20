# The engine itself ships as a prebuilt shared library.
vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO openpitkit/pit
  REF "v0.9.1"
  SHA512 6a917f58799233204953ee9a484ca4264c8e7ac9a77c2ec5d61d4380f5199c7378ac7aa616d5c987795432eded62b7e17bf62ecd50e9c0803805c3fc1692b943)

# Select the engine for the target triplet and supply it to both the package
# build and the exported config.
if(VCPKG_TARGET_IS_WINDOWS)
  if(NOT VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    message(FATAL_ERROR
      "openpit: no prebuilt engine for windows-${VCPKG_TARGET_ARCHITECTURE}")
  endif()
  set(openpit_runtime_asset "openpit-ffi--windows-amd64-openpit_ffi.dll")
  set(openpit_runtime_sha512 "f89dd239b76501efcc80300d051b04ccf1c84483ac468aabdd56a220f757556b13680d9b264f4c58112f4a73e593d95c845d09e1f669428fdded5de7c5f2bb7d")
  set(openpit_runtime_file "openpit_ffi.dll")
  set(openpit_implib_asset "openpit-ffi--windows-amd64-openpit_ffi.dll.lib")
  set(openpit_implib_sha512 "8447958468ef2516eafee4eb6b5715a14071bfa9c402f6140d7a03c91ff6b8bb60243bd7b7711ca6bf446a067ab25695edb5a27cc5f6295d397501714e641d5b")
  set(openpit_implib_file "openpit_ffi.lib")
elseif(VCPKG_TARGET_IS_OSX)
  set(openpit_runtime_file "libopenpit_ffi.dylib")
  if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(openpit_runtime_asset "openpit-ffi--darwin-arm64-libopenpit_ffi.dylib")
    set(openpit_runtime_sha512 "68138fea98a402dcaf4a6f163839aa0dcae6057e29a3dfcd21082db1b13d1228b5fe1794f74781c4c00e23231828528e5e4b76b96735d7fb216f53ec7e1540fb")
  elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(openpit_runtime_asset "openpit-ffi--darwin-amd64-libopenpit_ffi.dylib")
    set(openpit_runtime_sha512 "c5d6bb38926b9b5639032de2caf26e3c3fa2f83fbd6f97454bf5720a4122cca215398275c6b91a4575e5341ca46f283e3bf2d029f92e4971d800170c29b7c267")
  else()
    message(FATAL_ERROR
      "openpit: no prebuilt engine for osx-${VCPKG_TARGET_ARCHITECTURE}")
  endif()
elseif(VCPKG_TARGET_IS_LINUX)
  set(openpit_runtime_file "libopenpit_ffi.so")
  if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(openpit_runtime_asset "openpit-ffi--linux-arm64-libopenpit_ffi.so")
    set(openpit_runtime_sha512 "7007256e9e4f9c2c617bd6783800ffdfb36c05611579af830aa3521027653b63ec563cfba0cab3645252c159b03ada984f867174aa1b8b28c0063a899e9a6c74")
  elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(openpit_runtime_asset "openpit-ffi--linux-amd64-libopenpit_ffi.so")
    set(openpit_runtime_sha512 "52f3fdbeb8d74b397baa6e8044464469893de397e895cbb1117eb4d8dc313518c6dc5610ae6a56cb791beb3f1f2b3bfa419786e6aa608a7528118a6f6ac75c1d")
  else()
    message(FATAL_ERROR
      "openpit: no prebuilt engine for linux-${VCPKG_TARGET_ARCHITECTURE}")
  endif()
else()
  message(FATAL_ERROR "openpit: unsupported target platform")
endif()

vcpkg_download_distfile(openpit_runtime_path
  URLS "https://github.com/openpitkit/pit/releases/download/v0.9.1/${openpit_runtime_asset}"
  FILENAME "openpit-${VERSION}-${openpit_runtime_asset}"
  SHA512 "${openpit_runtime_sha512}")

set(openpit_runtime_options
  "-DOPENPIT_RUNTIME_LIBRARY=${openpit_runtime_path}")
if(VCPKG_TARGET_IS_WINDOWS)
  vcpkg_download_distfile(openpit_implib_path
    URLS "https://github.com/openpitkit/pit/releases/download/v0.9.1/${openpit_implib_asset}"
    FILENAME "openpit-${VERSION}-${openpit_implib_asset}"
    SHA512 "${openpit_implib_sha512}")
  list(APPEND openpit_runtime_options
    "-DOPENPIT_RUNTIME_IMPORT_LIBRARY=${openpit_implib_path}")
endif()

# The C++ layer is a header-only wrapper around the C ABI, so one
# configuration of its CMake package covers every consumer. The package
# installs the engine it was given and exports it from its own config.
block(SCOPE_FOR VARIABLES)
  set(VCPKG_BUILD_TYPE release)
  vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/bindings/cpp"
    OPTIONS
      ${openpit_runtime_options}
      "-DOPENPIT_BUNDLE_RUNTIME=ON"
      "-DOPENPIT_CPP_BUILD_TESTS=OFF"
      "-DOPENPIT_CPP_CHECK_HEADERS=ON"
      "-DOPENPIT_PACKAGE_VERSION=0.9.1"
      "-DOPENPIT_RUNTIME_VERSION=0.9.1")
  vcpkg_cmake_install()
  vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/OpenPit)
endblock()

# The engine is released in one flavour: it links its C runtime statically,
# and nothing CRT-owned crosses its C ABI, so the same binary serves Debug
# consumers. A triplet that builds both configurations gets it under debug/
# as well.
if(NOT VCPKG_BUILD_TYPE)
  if(VCPKG_TARGET_IS_WINDOWS)
    file(INSTALL "${CURRENT_PACKAGES_DIR}/bin/${openpit_runtime_file}"
      DESTINATION "${CURRENT_PACKAGES_DIR}/debug/bin")
    file(INSTALL "${CURRENT_PACKAGES_DIR}/lib/${openpit_implib_file}"
      DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
  else()
    file(INSTALL "${CURRENT_PACKAGES_DIR}/lib/${openpit_runtime_file}"
      DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
  endif()
endif()

vcpkg_install_copyright(FILE_LIST
  "${SOURCE_PATH}/LICENSE"
  "${SOURCE_PATH}/THIRD-PARTY-LICENSES")
