package Apache::TestHandler;

use strict;
use warnings FATAL => 'all';

use Apache::Test ();
use Apache::TestRequest ();

use Apache::Const -compile => qw(OK NOT_FOUND SERVER_ERROR);

#some utility handlers for testing hooks other than response
#see modperl-2.0/t/hooks/TestHooks/authen.pm

#compat with 1.xx
my $send_http_header = Apache->can('send_http_header') || sub {};
my $print = Apache->can('print') || Apache::RequestRec->can('puts');

sub ok {
    my $r = shift;
    $r->$send_http_header;
    $r->content_type('text/plain');
    $r->$print("ok");
    0;
}

sub ok1 {
    my $r = shift;
    Apache::Test::plan($r, tests => 1);
    Apache::Test::ok(1);
    0;
}

# a fixup handler to be used when a few requests need to be run
# against the same perl interpreter, in situations where there is more
# than one client running. For an example of use see
# modperl-2.0/t/response/TestModperl/interp.pm and
# modperl-2.0/t/modperl/interp.t
#
# this handler expects the header X-PerlInterpreter in the request
# - if none is set, Apache::SERVER_ERROR is returned
# - if its value eq 'tie', instance's global UUID is assigned and
#   returned via the same header
# - otherwise if its value is not the same the stored instance's
#   global UUID Apache::NOT_FOUND is returned
#
# in addition $same_interp_counter counts how many times this instance of
# pi has been called after the reset 'tie' request (inclusive), this
# value can be retrieved with Apache::TestHandler::same_interp_counter()
my $same_interp_id = "";
# keep track of how many times this instance was called after the reset
my $same_interp_counter = 0;
sub same_interp_counter { $same_interp_counter }
sub same_interp_fixup {
    my $r = shift;
    my $interp = $r->headers_in->get(Apache::TestRequest::INTERP_KEY);

    unless ($interp) {
        # shouldn't be requesting this without an INTERP header
        return Apache::SERVER_ERROR;
    }

    my $id = $same_interp_id;
    if ($interp eq 'tie') { #first request for an interpreter instance
        # unique id for this instance
        require APR::UUID;
        $same_interp_id = $id = APR::UUID->new->format;
        $same_interp_counter = 0; #reset the counter
    }
    elsif ($interp ne $same_interp_id) {
        # this is not the request interpreter instance
        return Apache::NOT_FOUND;
    }

    $same_interp_counter++;

    # so client can save the created instance id or check the existing
    # value
    $r->headers_out->set(Apache::TestRequest::INTERP_KEY, $id);

    return Apache::OK;
}

1;
__END__
