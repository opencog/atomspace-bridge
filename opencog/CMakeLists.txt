
DECLARE_GUILE_CONFIG_TARGET(SCM_CONFIG "opencog fdi-config" "ATOMSPACE_TEST")

ADD_SUBDIRECTORY (persist)

# ------------------------------------------------------------------
ADD_GUILE_MODULE (FILES
   scm/persist-foreign.scm
   MODULE_DESTINATION "${GUILE_SITE_DIR}/opencog"
)

WRITE_GUILE_CONFIG(${GUILE_BIN_DIR}/opencog/fdi-config.scm SCM_CONFIG TRUE)

WRITE_GUILE_CONFIG(${GUILE_BIN_DIR}/opencog/fdi-config-installable.scm SCM_CONFIG FALSE)
INSTALL(FILES ${GUILE_BIN_DIR}/opencog/fdi-config-installable.scm DESTINATION ${GUILE_SITE_DIR}/opencog RENAME fdi-config.scm)
