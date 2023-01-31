
DECLARE_GUILE_CONFIG_TARGET(SCM_CONFIG "opencog bridge-config" "ATOMSPACE_TEST")

ADD_SUBDIRECTORY (persist)

# ------------------------------------------------------------------
ADD_GUILE_MODULE (FILES
   scm/persist-bridge.scm
   MODULE_DESTINATION "${GUILE_SITE_DIR}/opencog"
)

WRITE_GUILE_CONFIG(${GUILE_BIN_DIR}/opencog/bridge-config.scm SCM_CONFIG TRUE)

WRITE_GUILE_CONFIG(${GUILE_BIN_DIR}/opencog/bridge-config-installable.scm SCM_CONFIG FALSE)
INSTALL(FILES ${GUILE_BIN_DIR}/opencog/bridge-config-installable.scm DESTINATION ${GUILE_SITE_DIR}/opencog RENAME bridge-config.scm)
