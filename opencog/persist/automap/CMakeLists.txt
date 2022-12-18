# Uncomment this if SQL is installed.
# ADD_DEFINITIONS(-DHAVE_SQL_STORAGE)

ADD_LIBRARY (persist-fdi
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

# ADD_GUILE_EXTENSION(SCM_CONFIG persist-fdi "opencog-ext-path-persist-fdi")

#ADD_GUILE_MODULE (FILES
#	opencog/persist-fdi.scm
#	DEPENDS persist-fdi
##	COMPILE
#)

INSTALL (TARGETS persist-fdi EXPORT AtomSpaceAutoMapTargets
	DESTINATION "lib${LIB_DIR_SUFFIX}/opencog"
)
