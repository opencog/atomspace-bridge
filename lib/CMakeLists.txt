
# CMake boilerplate mumbo-jumbo that does something.

include(CMakePackageConfigHelpers)

set(ConfigPackageLocation lib/cmake/AtomSpaceAutoMap)

install(EXPORT AtomSpaceAutoMapTargets
	FILE AtomSpaceAutoMapTargets.cmake
	DESTINATION ${ConfigPackageLocation}
)

SET(SEMANTIC_VERSION 0.0.1)

configure_package_config_file(AtomSpaceAutoMapConfig.cmake.in
	${CMAKE_CURRENT_BINARY_DIR}/AtomSpaceAutoMapConfig.cmake
	INSTALL_DESTINATION ${ConfigPackageLocation}
	PATH_VARS CMAKE_INSTALL_PREFIX
)

write_basic_package_version_file(
	"${CMAKE_CURRENT_BINARY_DIR}/AtomSpaceAutoMapConfigVersion.cmake"
	VERSION ${SEMANTIC_VERSION}
	COMPATIBILITY SameMajorVersion
)

INSTALL(FILES
	${CMAKE_CURRENT_BINARY_DIR}/AtomSpaceAutoMapConfigVersion.cmake
	${CMAKE_CURRENT_BINARY_DIR}/AtomSpaceAutoMapConfig.cmake
	DESTINATION ${ConfigPackageLocation}
)
