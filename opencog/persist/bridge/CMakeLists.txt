
ADD_LIBRARY (persist-bridge SHARED
	BridgePersistSCM.cc
	BridgeStorage.cc
	SQLReader.cc
	ll-pg-cxx.cc
	llapi.cc
)

# ADD_DEPENDENCIES(persist-bridge opencog_atom_types atomspace)

TARGET_LINK_LIBRARIES(persist-bridge
	persist
	storage-types
	atomspace
	${PGSQL_LIBRARIES}
)

# The `persist-bridge` below is the name of the shared lib, not the module.
ADD_GUILE_EXTENSION(SCM_CONFIG persist-bridge "opencog-ext-path-persist-bridge")

INSTALL (TARGETS persist-bridge EXPORT AtomSpaceAutoMapTargets
	DESTINATION "lib${LIB_DIR_SUFFIX}/opencog"
)
