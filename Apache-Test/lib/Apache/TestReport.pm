# Copyright 2001-2004 The Apache Software Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
package Apache::TestReport;

use strict;
use warnings FATAL => 'all';

use Apache::Test ();
use Apache::TestConfig ();

use File::Spec::Functions qw(catfile);
use File::Find;

sub new {
    my $class = shift;
    bless { @_ }, $class;
}

# generate t/REPORT script (or a different filename) which will drive
# Apache::TestReport
sub generate_script {
    my ($class, $file) = @_;

    $file ||= catfile 't', 'REPORT';

    my $content = join "\n",
        "BEGIN { eval { require blib && blib->import; } }",
        Apache::TestConfig->modperl_2_inc_fixup,
        Apache::TestConfig->perlscript_header,
        "use $class;",
        "$class->new(\@ARGV)->run;";

    Apache::Test::basic_config()->write_perlscript($file, $content);
}

sub replace {
    my($self, $template) = @_;

    $template =~ s{\@(\w+)\@} {
        my $method = lc $1;
        eval { $self->$method() } || $self->{$1} || '';
    }eg;

    $template;
}

sub run {
    my $self = shift;

    print $self->replace($self->template);
}

sub config { Apache::TestConfig::as_string() }

sub report_to { 'test-dev@httpd.apache.org' }

sub postit_note {
    my $self = shift;

    my($to, $where) = split '@', $self->report_to;

    return <<EOF;
Note: Complete the rest of the details and post this bug report to
$to <at> $where. To subscribe to the list send an empty
email to $to-subscribe\@$where.
EOF
}

sub executable { $0 }

my $core_dump;
sub core_dump {
    my $self = shift;

    $core_dump = "";

    if (eval { require Devel::GDB }) {
        find(\&dump_core_file, 't')
    }

    $core_dump || '  [CORE TRACE COMES HERE]';
}

sub dump_core_file {
    return unless /^core(\.\d+)?$/;

    my $core = $_;
    my $gdb = new Devel::GDB ();
    my $test_config = Apache::TestConfig->new({thaw=>1});
    my $httpd = $test_config->{vars}->{httpd};

    return unless defined $httpd;

    $core_dump .= join '',
           $gdb->get("file $httpd"),
           $gdb->get('sharedlibrary'),
           $gdb->get("core $core"),
           $gdb->get('info threads'),
           $gdb->get('thread apply all bt');
}

sub date { scalar gmtime() . " GMT" }

sub template {
<<'EOI'
-------------8<---------- Start Bug Report ------------8<----------
1. Problem Description:

  [DESCRIBE THE PROBLEM HERE]

2. Used Components and their Configuration:

@CONFIG@

3. This is the core dump trace: (if you get a core dump):

@CORE_DUMP@

This report was generated by @EXECUTABLE@ on @DATE@.

-------------8<---------- End Bug Report --------------8<----------

@POSTIT_NOTE@

EOI

}

1;
__END__

=head1 NAME

Apache::TestReport - A parent class for generating bug/success reports

=head1 Synopsis

  use Apache::TestReport;
  Apache::TestReport->new(@ARGV)->run;

=head1 Description

This class is used to generate a bug or a success report, providing
information about the system the code was running on.

=head1 Overridable Methods

=head2 config

return the information about user's system

=head2 report_to

return a string containing the email address the report should be sent
to

=head2 postit_note

return a string to close the report with, e.g.:

      my($to, $where) = split '@', $self->report_to;
      return <<EOF;
  Note: Complete the rest of the details and post this bug report to
  $to <at> $where. To subscribe to the list send an empty
  email to $to-subscribe\@$where.


=cut

