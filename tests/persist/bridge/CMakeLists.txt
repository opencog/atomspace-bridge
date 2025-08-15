
# The atom_types.h file is written to the build directory
INCLUDE_DIRECTORIES(${CMAKE_BINARY_DIR})

LINK_LIBRARIES(persist-bridge atomspace)

# ADD_CXXTEST(SchemaLoadUTest)
