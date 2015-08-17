# $Id$

# This file contains functions we need but Rakudo doesn't yet support

.namespace ['ModPerl6';'Fudge']

# NAME: resolve_sub
# PURPOSE: look up and return subroutine PMC in a namespace
# FUDGES: resolving subs with interpolated namespaces
.sub resolve_sub
    .param string ns
    .param string name

    $P0 = split '::', ns
    $P1 = get_hll_global $P0, name
    $I0 = isnull $P1
    if $I0 goto no_sub
  isa_sub:
    $I0 = isa $P1, 'Sub'
    if $I0 goto return_sub
  no_sub:
    $P1 = new 'Failure'
  return_sub:
    .return($P1)
.end

# NAME: call_sub_with_namespace
# PURPOSE: call a sub defined in a namespace
# FUDGES: calling subs with interpolated namespaces
.sub call_sub_with_namespace
    .param string ns
    .param string name
    .param pmc args :slurpy

    $P0 = 'resolve_sub'(ns, name)
    unless $P0 goto no_sub
    $P1 = $P0(args :flat)
    goto return_result
  no_sub:
    $P1 = new 'Failure'
  return_result:
    .return($P1)
.end

# NAME: call_class_method
# PURPOSE: call a class method
# FUDGES: calling a class method when class is interpolated
.sub call_class_method
    .param string ns
    .param string meth
    .param pmc args :slurpy

    $P0 = split '::', ns
    $I0 = elements $P0
    if $I0 > 1 goto nested_namespace
    $S0 = $P0
    $P1 = get_hll_global $S0
    goto call_method
  nested_namespace:
    $S0 = pop $P0
    $P1 = get_hll_global $P0, $S0
  call_method:
    if null $P1 goto no_class
    $P0 = $P1.meth(args :flat)
    goto return_result
  no_class:
    $P0 = new 'Failure'
  return_result:
    .return($P0)
.end

# NAME: setenv
# PURPOSE: sets the value of an environment variable
# FUDGES: %*ENV<foo> = 'bar' and its workaround %*ENV<foo> := 'bar';
.sub setenv
    .param pmc key
    .param pmc val

    $P0 = get_hll_global '%ENV'
    $P0[key] = val
.end
