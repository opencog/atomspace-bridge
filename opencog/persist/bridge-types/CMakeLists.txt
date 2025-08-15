# Generate the atom types
OPENCOG_GEN_CXX_ATOMTYPES(atom_types.script
	atom_types.h
	atom_types.definitions
	atom_types.inheritance)

OPENCOG_GEN_SCM_ATOMTYPES(atom_types.script persist_bridge_types.scm)
OPENCOG_GEN_PYTHON_ATOMTYPES(atom_types.script persist_bridge_types.pyx)

ADD_CUSTOM_TARGET(persist_bridge_atom_types
	DEPENDS atom_types.h persist_bridge_types.scm persist_bridge_types.pyx)

# Add the link directory before the library
LINK_DIRECTORIES(/usr/local/lib/opencog)

# Build the shared library
ADD_LIBRARY (persist-bridge-types SHARED
	atom_types_init.cc
)

# The atom_types.h file is written to the build directory
TARGET_INCLUDE_DIRECTORIES(persist-bridge-types PRIVATE ${CMAKE_BINARY_DIR})

TARGET_LINK_LIBRARIES(persist-bridge-types
	storage-types
	${ATOMSPACE_STORAGE_LIBRARIES}
	${ATOMSPACE_LIBRARIES}
)

ADD_DEPENDENCIES(persist-bridge-types persist_bridge_atom_types)

# Install targets
INSTALL (TARGETS persist-bridge-types EXPORT AtomSpaceAutoMapTargets
	DESTINATION "lib${LIB_DIR_SUFFIX}/opencog"
)

INSTALL (FILES
	${CMAKE_CURRENT_BINARY_DIR}/atom_types.h
	DESTINATION "include/opencog/persist/bridge-types"
)

ADD_GUILE_MODULE (FILES
	${CMAKE_CURRENT_BINARY_DIR}/persist_bridge_types.scm
	MODULE_DESTINATION "${GUILE_SITE_DIR}/opencog/persist/bridge-types"
	DEPENDS persist_bridge_atom_types
)

ADD_GUILE_EXTENSION(SCM_CONFIG persist-bridge-types "opencog-ext-path-persist-bridge-types")