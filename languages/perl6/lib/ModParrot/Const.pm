# $Id

module ModParrot::Const;

q:PIR <
    .include "iterator.pasm"

    # don't proceed unless we're actually running
    $P0 = get_root_global '!MODPARROT_RUNTIME'
    if null $P0 goto done

    $P0 = get_root_global ['ModParrot'; 'Constants'], 'table'
    $P1 = new 'Iterator', $P0
    $P1 = .ITERATE_FROM_START
  iter_start:
    unless $P1 goto iter_end
    $S0 = shift $P1
    $I0 = $P0[$S0]
    $P3 = new 'Integer'
    $P3 = $I0
    $S1 = '$'
    $S1 .= $S0
    set_hll_global ['ModParrot'; 'Const'], $S1, $P3
    goto iter_start
  iter_end:
  done:
>;
