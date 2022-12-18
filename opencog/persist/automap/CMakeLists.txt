
ADD_LIBRARY (persist-fdi SHARED
	ForeignPersistSCM.cc
	ForeignStorage.cc
	ll-pg-cxx.cc
	llapi.cc
)

# ADD_DEPENDENCIES(persist-fdi opencog_atom_types atomspace)

TARGET_LINK_LIBRARIES(persist-fdi
	persist
	storage-types
	atomspace
)

# The `persist-fdi` below is the name of the shared lib, not the module.
ADD_GUILE_EXTENSION(SCM_CONFIG persist-fdi "opencog-ext-path-persist-fdi")

INSTALL (TARGETS persist-fdi EXPORT AtomSpaceAutoMapTargets
	DESTINATION "lib${LIB_DIR_SUFFIX}/opencog"
)
