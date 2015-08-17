use Apache::Test qw(-withtestmore);
use Apache::TestRequest;
use Apache::TestUtil qw(t_cmp);

my ($content, $res);

plan tests => 2, need qw(LWP mod_auth_basic.c);

# Apache::RequestRec->RequestRec-get_basic_auth_pw
$res = GET '/parrot-test/RequestRec-get_basic_auth_pw';
is($res->code, 401, 'unauthorized access');

# Apache::RequestRec->RequestRec-get_basic_auth_pw
$res = GET '/parrot-test/RequestRec-get_basic_auth_pw',
    username => 'joeuser', password => 'password';
chomp($content = $res->content);
is($content, 'Access granted.',
    'joeuser:password granted access');
