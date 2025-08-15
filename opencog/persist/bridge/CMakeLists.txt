
# Add the link directory before the library
LINK_DIRECTORIES(/usr/local/lib/opencog)

ADD_LIBRARY (persist-bridge SHARED
	BridgePersistSCM.cc
	BridgeStorage.cc
	SQLReader.cc
	ll-pg-cxx.cc
	llapi.cc
)

# The atom_types.h file is written to the build directory
TARGET_INCLUDE_DIRECTORIES(persist-bridge PRIVATE ${CMAKE_BINARY_DIR})

TARGET_LINK_LIBRARIES(persist-bridge
	persist-bridge-types
	${ATOMSPACE_STORAGE_LIBRARIES}
	${ATOMSPACE_LIBRARIES}
	${PGSQL_LIBRARIES}
)

ADD_DEPENDENCIES(persist-bridge persist_bridge_atom_types)

# The `persist-bridge` below is the name of the shared lib, not the module.
ADD_GUILE_EXTENSION(SCM_CONFIG persist-bridge "opencog-ext-path-persist-bridge")

INSTALL (TARGETS persist-bridge EXPORT AtomSpaceAutoMapTargets
	DESTINATION "lib${LIB_DIR_SUFFIX}/opencog"
)
