use strict;
use warnings;

use Test::More;

use EDG::WP4::CCM::CCfg;

BEGIN {
    # Force typed json for improved testing
    # Use BEGIN to make sure it is executed before the import from Test::Quattor
    ok(EDG::WP4::CCM::CCfg::_setCfgValue('json_typed', 1), 'json_typed enabled');
}

use Test::Quattor qw(format);
use EDG::WP4::CCM::TextRender qw(ccm_format @CCM_FORMATS);
use Test::Quattor::Object;
use Test::Quattor::TextRender::Base;
use XML::Parser;

ok(EDG::WP4::CCM::CCfg::getCfgValue('json_typed'), 'json_typed (still) enabled');

is_deeply(\@CCM_FORMATS,
          [qw(json jsonpretty ncmquery pan pancxml query tabcompletion yaml)],
          "Expected supported CCM formats"
    );

my $cfg = get_config_for_profile("format");

my $caf_trd = mock_textrender();
my $log = Test::Quattor::Object->new();


# generate output for $path and $format, return text
# if squash is true, squash the whitespace
sub test_format
{
    my ($path, $format, $squash) = @_;

    my $el = $cfg->getElement($path);
    my $fmt = ccm_format($format, $el);
    isa_ok($fmt, 'EDG::WP4::CCM::TextRender', "a EDG::WP4::CCM::TextRender instance");
    my $txt = "$fmt";

    $txt =~ s/\s//g if $squash; # squash all whitespace

    return $txt;
}

=pod

unsupported format

=cut

my $el = $cfg->getElement("/");
ok(! defined(ccm_format('notasupportedformat', $el)),
   "ccm_format returns undef for unsupported format");

=pod

=head2 json

=cut

is(test_format('/', 'json', 0),
   '{"a":1,"b":1.5,"c":{"f":false,"t":true},"d":"test","g":[{"g1":10,"g2":20},{"g1":11,"g2":21}]}'."\n",
   "JSON format");

# JSON doesn't like scalars
is(test_format('/a', 'json', 0),
   '',
   "JSON format for scalar/single element (empty string due to failed rendering and _stringify)");

is(test_format('/g', 'json', 0),
   '[{"g1":10,"g2":20},{"g1":11,"g2":21}]'."\n",
   "JSON format for list element");

=pod

=head2 yaml

=cut

is(test_format('/', 'yaml', 1),
   "---a:1b:1.5c:f:falset:trued:testg:-g1:10g2:20-g1:11g2:21",
   "YAML format");

is(test_format('/a', 'yaml', 1),
   '---1',
   "YAML format for scalar/single element");

is(test_format('/g', 'yaml', 1),
   '----g1:10g2:20-g1:11g2:21',
   "YAML format for list element");

=pod

=head2 pan

Test pan format (more tests in TT testsuite)

=cut

is(test_format('/', 'pan', 1),
   '"/a"=1;#long"/b"=1.5;#double"/c/f"=false;#boolean"/c/t"=true;#boolean"/d"="test";#string"/g/0/g1"=10;#long"/g/0/g2"=20;#long"/g/1/g1"=11;#long"/g/1/g2"=21;#long',
   "pan format");

# TODO: should this be relative path?
is(test_format('/a', 'pan', 1),
   '"/a"=1;#long',
   "pan format for scalar/single element");

is(test_format('/g', 'pan', 1),
   '"/g/0/g1"=10;#long"/g/0/g2"=20;#long"/g/1/g1"=11;#long"/g/1/g2"=21;#long',
   "pan format for list element");

=pod

=head2 pancxml

Test pancxml format (more tests in TT testsuite)

=cut

my $txt = test_format('/', 'pancxml', 0);

my $p = XML::Parser->new(Style => 'Tree');
my $t;
eval { $t = $p->parse($txt); };
ok(! @$, "No XML parsing errors");

$txt =~ s/\s//g; # squash all whitespace
is($txt,
   '<?xmlversion="1.0"encoding="UTF-8"?><nlistformat="pan"name="profile"><longname="a">1</long><doublename="b">1.5</double><nlistname="c"><booleanname="f">false</boolean><booleanname="t">true</boolean></nlist><stringname="d">test</string><listname="g"><nlist><longname="g1">10</long><longname="g2">20</long></nlist><nlist><longname="g1">11</long><longname="g2">21</long></nlist></list></nlist>',
   "pancxml format");

# TODO: looks a bit strange?
is(test_format('/a', 'pancxml', 1),
   '<?xmlversion="1.0"encoding="UTF-8"?><longformat="pan"name="profile">1</long>',
   "pancxml format for scalar/single element");

is(test_format('/g', 'pancxml', 1),
   '<?xmlversion="1.0"encoding="UTF-8"?><listformat="pan"name="profile"><nlist><longname="g1">10</long><longname="g2">20</long></nlist><nlist><longname="g1">11</long><longname="g2">21</long></nlist></list>',
   "pancxml format for list element");

=pod

=head2 tabcompletion

Test tabcompletion format (more tests in TT testsuite)

=cut

is(test_format('/', 'tabcompletion', 1),
   '//a/b/c//c/f/c/t/d/g//g/0//g/0/g1/g/0/g2/g/1//g/1/g1/g/1/g2',
   "tabcompletion format");

is(test_format('/a', 'tabcompletion', 1),
   '/a',
   "tabcompletion format for scalar/single element");

is(test_format('/g', 'tabcompletion', 1),
   '/g//g/0//g/0/g1/g/0/g2/g/1//g/1/g1/g/1/g2',
   "tabcompletion format for list element");


=pod

=head2 query

Test query format (more tests in TT testsuite)

=cut

is(test_format('/', 'query', 1),
   '+-/$a:1$b:1.5+-c$f:false$t:true$d:\'test\'+-g+-0$g1:10$g2:20+-1$g1:11$g2:21',
   "query format");

is(test_format('/a', 'query', 1),
   '$a:1',
   "query format for scalar/single element");

is(test_format('/g', 'query', 1),
   '+-/g+-0$g1:10$g2:20+-1$g1:11$g2:21',
   "query format for list element");

=pod

=head2 ncmquery

Test ncmquery format (more tests in TT testsuite)

=cut

is(test_format('/', 'ncmquery', 1),
   '+-/$a:(long)\'1\'$b:(double)\'1.5\'+-c$f:(boolean)\'false\'$t:(boolean)\'true\'$d:(string)\'test\'+-g+-0$g1:(long)\'10\'$g2:(long)\'20\'+-1$g1:(long)\'11\'$g2:(long)\'21\'',
   "ncmquery format");

is(test_format('/a', 'ncmquery', 1),
   '$a:(long)\'1\'',
   "ncmquery format for scalar/single element");

is(test_format('/g', 'ncmquery', 1),
   '+-/g+-0$g1:(long)\'10\'$g2:(long)\'20\'+-1$g1:(long)\'11\'$g2:(long)\'21\'',
   "ncmquery format for list element");


done_testing();
