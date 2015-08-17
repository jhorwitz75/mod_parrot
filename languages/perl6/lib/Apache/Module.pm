# $Id$

module Apache::Module;

q:PIR<
    # don't proceed unless we're actually running
    $P0 = get_root_global '!MODPARROT_RUNTIME'
    if null $P0 goto done

    $P0 = get_root_namespace ['parrot';'ModParrot';'Apache';'Module']
    $P1 = new 'Exporter'
    $P1.'import'($P0 :named('source'), 'add get_config' :named('globals'))
  done:
>;
