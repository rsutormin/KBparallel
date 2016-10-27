package KBparallel::KBparallelClient;

use JSON::RPC::Client;
use POSIX;
use strict;
use Data::Dumper;
use URI;
use Bio::KBase::Exceptions;
use Time::HiRes;
my $get_time = sub { time, 0 };
eval {
    require Time::HiRes;
    $get_time = sub { Time::HiRes::gettimeofday() };
};

use Bio::KBase::AuthToken;

# Client version should match Impl version
# This is a Semantic Version number,
# http://semver.org
our $VERSION = "0.1.0";

=head1 NAME

KBparallel::KBparallelClient

=head1 DESCRIPTION





=cut

sub new
{
    my($class, $url, @args) = @_;
    

    my $self = {
	client => KBparallel::KBparallelClient::RpcClient->new,
	url => $url,
	headers => [],
    };
    my %arg_hash = @args;
    $self->{async_job_check_time} = 0.1;
    if (exists $arg_hash{"async_job_check_time_ms"}) {
        $self->{async_job_check_time} = $arg_hash{"async_job_check_time_ms"} / 1000.0;
    }
    $self->{async_job_check_time_scale_percent} = 150;
    if (exists $arg_hash{"async_job_check_time_scale_percent"}) {
        $self->{async_job_check_time_scale_percent} = $arg_hash{"async_job_check_time_scale_percent"};
    }
    $self->{async_job_check_max_time} = 300;  # 5 minutes
    if (exists $arg_hash{"async_job_check_max_time_ms"}) {
        $self->{async_job_check_max_time} = $arg_hash{"async_job_check_max_time_ms"} / 1000.0;
    }
    my $service_version = undef;
    if (exists $arg_hash{"service_version"}) {
        $service_version = $arg_hash{"async_version"};
    }
    $self->{service_version} = $service_version;

    chomp($self->{hostname} = `hostname`);
    $self->{hostname} ||= 'unknown-host';

    #
    # Set up for propagating KBRPC_TAG and KBRPC_METADATA environment variables through
    # to invoked services. If these values are not set, we create a new tag
    # and a metadata field with basic information about the invoking script.
    #
    if ($ENV{KBRPC_TAG})
    {
	$self->{kbrpc_tag} = $ENV{KBRPC_TAG};
    }
    else
    {
	my ($t, $us) = &$get_time();
	$us = sprintf("%06d", $us);
	my $ts = strftime("%Y-%m-%dT%H:%M:%S.${us}Z", gmtime $t);
	$self->{kbrpc_tag} = "C:$0:$self->{hostname}:$$:$ts";
    }
    push(@{$self->{headers}}, 'Kbrpc-Tag', $self->{kbrpc_tag});

    if ($ENV{KBRPC_METADATA})
    {
	$self->{kbrpc_metadata} = $ENV{KBRPC_METADATA};
	push(@{$self->{headers}}, 'Kbrpc-Metadata', $self->{kbrpc_metadata});
    }

    if ($ENV{KBRPC_ERROR_DEST})
    {
	$self->{kbrpc_error_dest} = $ENV{KBRPC_ERROR_DEST};
	push(@{$self->{headers}}, 'Kbrpc-Errordest', $self->{kbrpc_error_dest});
    }

    #
    # This module requires authentication.
    #
    # We create an auth token, passing through the arguments that we were (hopefully) given.

    {
	my $token = Bio::KBase::AuthToken->new(@args);
	
	if (!$token->error_message)
	{
	    $self->{token} = $token->token;
	    $self->{client}->{token} = $token->token;
	}
        else
        {
	    #
	    # All methods in this module require authentication. In this case, if we
	    # don't have a token, we can't continue.
	    #
	    die "Authentication failed: " . $token->error_message;
	}
    }

    my $ua = $self->{client}->ua;	 
    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $ua->timeout($timeout);
    bless $self, $class;
    #    $self->_validate_version();
    return $self;
}

sub _check_job {
    my($self, @args) = @_;
# Authentication: ${method.authentication}
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _check_job (received $n, expecting 1)");
    }
    {
        my($job_id) = @args;
        my @_bad_arguments;
        (!ref($job_id)) or push(@_bad_arguments, "Invalid type for argument 0 \"job_id\" (it should be a string)");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _check_job:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_check_job');
        }
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "KBparallel._check_job",
        params => \@args});
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_check_job',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
                          );
        } else {
            return $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _check_job",
                        status_line => $self->{client}->status_line,
                        method_name => '_check_job');
    }
}




=head2 run

  $rep = $obj->run($input_params)

=over 4

=item Parameter and return types

=begin html

<pre>
$input_params is a KBparallel.KBparallelrunInputParams
$rep is a KBparallel.KBparallelOutputObj
KBparallelrunInputParams is a reference to a hash where the following keys are defined:
	module_name has a value which is a string
	method_name has a value which is a string
	service_ver has a value which is a string
	method_params has a value which is a reference to a list where each element is an UnspecifiedObject, which can hold any non-null object
	client_class_name has a value which is a string
	time_limit has a value which is an int
KBparallelOutputObj is a reference to a hash where the following keys are defined:
	report has a value which is a KBaseReport.Report
	msg has a value which is a string
Report is a reference to a hash where the following keys are defined:
	text_message has a value which is a string
	warnings has a value which is a reference to a list where each element is a string
	objects_created has a value which is a reference to a list where each element is a KBaseReport.WorkspaceObject
	file_links has a value which is a reference to a list where each element is a KBaseReport.LinkedFile
	html_links has a value which is a reference to a list where each element is a KBaseReport.LinkedFile
	direct_html has a value which is a string
	direct_html_link_index has a value which is an int
WorkspaceObject is a reference to a hash where the following keys are defined:
	ref has a value which is a KBaseReport.ws_id
	description has a value which is a string
ws_id is a string
LinkedFile is a reference to a hash where the following keys are defined:
	handle has a value which is a KBaseReport.handle_ref
	description has a value which is a string
	name has a value which is a string
	URL has a value which is a string
handle_ref is a string

</pre>

=end html

=begin text

$input_params is a KBparallel.KBparallelrunInputParams
$rep is a KBparallel.KBparallelOutputObj
KBparallelrunInputParams is a reference to a hash where the following keys are defined:
	module_name has a value which is a string
	method_name has a value which is a string
	service_ver has a value which is a string
	method_params has a value which is a reference to a list where each element is an UnspecifiedObject, which can hold any non-null object
	client_class_name has a value which is a string
	time_limit has a value which is an int
KBparallelOutputObj is a reference to a hash where the following keys are defined:
	report has a value which is a KBaseReport.Report
	msg has a value which is a string
Report is a reference to a hash where the following keys are defined:
	text_message has a value which is a string
	warnings has a value which is a reference to a list where each element is a string
	objects_created has a value which is a reference to a list where each element is a KBaseReport.WorkspaceObject
	file_links has a value which is a reference to a list where each element is a KBaseReport.LinkedFile
	html_links has a value which is a reference to a list where each element is a KBaseReport.LinkedFile
	direct_html has a value which is a string
	direct_html_link_index has a value which is an int
WorkspaceObject is a reference to a hash where the following keys are defined:
	ref has a value which is a KBaseReport.ws_id
	description has a value which is a string
ws_id is a string
LinkedFile is a reference to a hash where the following keys are defined:
	handle has a value which is a KBaseReport.handle_ref
	description has a value which is a string
	name has a value which is a string
	URL has a value which is a string
handle_ref is a string


=end text

=item Description



=back

=cut

sub run
{
    my($self, @args) = @_;
    my $job_id = $self->_run_submit(@args);
    my $async_job_check_time = $self->{async_job_check_time};
    while (1) {
        Time::HiRes::sleep($async_job_check_time);
        $async_job_check_time *= $self->{async_job_check_time_scale_percent} / 100.0;
        if ($async_job_check_time > $self->{async_job_check_max_time}) {
            $async_job_check_time = $self->{async_job_check_max_time};
        }
        my $job_state_ref = $self->_check_job($job_id);
        if ($job_state_ref->{"finished"} != 0) {
            if (!exists $job_state_ref->{"result"}) {
                $job_state_ref->{"result"} = [];
            }
            return wantarray ? @{$job_state_ref->{"result"}} : $job_state_ref->{"result"}->[0];
        }
    }
}

sub _run_submit {
    my($self, @args) = @_;
# Authentication: required
    if ((my $n = @args) != 1) {
        Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
                                   "Invalid argument count for function _run_submit (received $n, expecting 1)");
    }
    {
        my($input_params) = @args;
        my @_bad_arguments;
        (ref($input_params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input_params\" (value was \"$input_params\")");
        if (@_bad_arguments) {
            my $msg = "Invalid arguments passed to _run_submit:\n" . join("", map { "\t$_\n" } @_bad_arguments);
            Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
                                   method_name => '_run_submit');
        }
    }
    my $context = undef;
    if ($self->{service_version}) {
        $context = {'service_ver' => $self->{service_version}};
    }
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "KBparallel._run_submit",
        params => \@args}, context => $context);
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
                           code => $result->content->{error}->{code},
                           method_name => '_run_submit',
                           data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
            );
        } else {
            return $result->result->[0];  # job_id
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method _run_submit",
                        status_line => $self->{client}->status_line,
                        method_name => '_run_submit');
    }
}

 


=head2 status

  $ret = $obj->status($input_params)

=over 4

=item Parameter and return types

=begin html

<pre>
$input_params is a KBparallel.KBparallelstatusInputParams
$ret is a KBparallel.KBparallelstatusOutputObj
KBparallelstatusInputParams is a reference to a hash where the following keys are defined:
	joblist has a value which is a reference to a list where each element is an int
KBparallelstatusOutputObj is a reference to a hash where the following keys are defined:
	num_jobs_checked has a value which is an int
	jobstatus has a value which is a reference to a list where each element is a string

</pre>

=end html

=begin text

$input_params is a KBparallel.KBparallelstatusInputParams
$ret is a KBparallel.KBparallelstatusOutputObj
KBparallelstatusInputParams is a reference to a hash where the following keys are defined:
	joblist has a value which is a reference to a list where each element is an int
KBparallelstatusOutputObj is a reference to a hash where the following keys are defined:
	num_jobs_checked has a value which is an int
	jobstatus has a value which is a reference to a list where each element is a string


=end text

=item Description



=back

=cut

 sub status
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function status (received $n, expecting 1)");
    }
    {
	my($input_params) = @args;

	my @_bad_arguments;
        (ref($input_params) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input_params\" (value was \"$input_params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to status:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'status');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "KBparallel.status",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'status',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method status",
					    status_line => $self->{client}->status_line,
					    method_name => 'status',
				       );
    }
}
 


=head2 cancel_run

  $ret = $obj->cancel_run($input_params)

=over 4

=item Parameter and return types

=begin html

<pre>
$input_params is a KBparallel.KBparallelcancel_runInput
$ret is a KBparallel.KBparallelcancel_runOutput
KBparallelcancel_runInput is a string
KBparallelcancel_runOutput is a string

</pre>

=end html

=begin text

$input_params is a KBparallel.KBparallelcancel_runInput
$ret is a KBparallel.KBparallelcancel_runOutput
KBparallelcancel_runInput is a string
KBparallelcancel_runOutput is a string


=end text

=item Description



=back

=cut

 sub cancel_run
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function cancel_run (received $n, expecting 1)");
    }
    {
	my($input_params) = @args;

	my @_bad_arguments;
        (!ref($input_params)) or push(@_bad_arguments, "Invalid type for argument 1 \"input_params\" (value was \"$input_params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to cancel_run:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'cancel_run');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "KBparallel.cancel_run",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'cancel_run',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method cancel_run",
					    status_line => $self->{client}->status_line,
					    method_name => 'cancel_run',
				       );
    }
}
 


=head2 getlog

  $ret = $obj->getlog($input_params)

=over 4

=item Parameter and return types

=begin html

<pre>
$input_params is a KBparallel.KBparallelgetlogInput
$ret is a KBparallel.KBparallelgetlogOutput
KBparallelgetlogInput is a string
KBparallelgetlogOutput is a string

</pre>

=end html

=begin text

$input_params is a KBparallel.KBparallelgetlogInput
$ret is a KBparallel.KBparallelgetlogOutput
KBparallelgetlogInput is a string
KBparallelgetlogOutput is a string


=end text

=item Description



=back

=cut

 sub getlog
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function getlog (received $n, expecting 1)");
    }
    {
	my($input_params) = @args;

	my @_bad_arguments;
        (!ref($input_params)) or push(@_bad_arguments, "Invalid type for argument 1 \"input_params\" (value was \"$input_params\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to getlog:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'getlog');
	}
    }

    my $url = $self->{url};
    my $result = $self->{client}->call($url, $self->{headers}, {
	    method => "KBparallel.getlog",
	    params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'getlog',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method getlog",
					    status_line => $self->{client}->status_line,
					    method_name => 'getlog',
				       );
    }
}
 
   

sub version {
    my ($self) = @_;
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "KBparallel.version",
        params => [],
    });
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(
                error => $result->error_message,
                code => $result->content->{code},
                method_name => 'getlog',
            );
        } else {
            return wantarray ? @{$result->result} : $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(
            error => "Error invoking method getlog",
            status_line => $self->{client}->status_line,
            method_name => 'getlog',
        );
    }
}

sub _validate_version {
    my ($self) = @_;
    my $svr_version = $self->version();
    my $client_version = $VERSION;
    my ($cMajor, $cMinor) = split(/\./, $client_version);
    my ($sMajor, $sMinor) = split(/\./, $svr_version);
    if ($sMajor != $cMajor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Major version numbers differ.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor < $cMinor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Client minor version greater than Server minor version.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor > $cMinor) {
        warn "New client version available for KBparallel::KBparallelClient\n";
    }
    if ($sMajor == 0) {
        warn "KBparallel::KBparallelClient version is $svr_version. API subject to change.\n";
    }
}

=head1 TYPES



=head2 KBparallelrunInputParams

=over 4



=item Description

run() method


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
module_name has a value which is a string
method_name has a value which is a string
service_ver has a value which is a string
method_params has a value which is a reference to a list where each element is an UnspecifiedObject, which can hold any non-null object
client_class_name has a value which is a string
time_limit has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
module_name has a value which is a string
method_name has a value which is a string
service_ver has a value which is a string
method_params has a value which is a reference to a list where each element is an UnspecifiedObject, which can hold any non-null object
client_class_name has a value which is a string
time_limit has a value which is an int


=end text

=back



=head2 KBparallelOutputObj

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
report has a value which is a KBaseReport.Report
msg has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
report has a value which is a KBaseReport.Report
msg has a value which is a string


=end text

=back



=head2 KBparallelstatusInputParams

=over 4



=item Description

status() method


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
joblist has a value which is a reference to a list where each element is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
joblist has a value which is a reference to a list where each element is an int


=end text

=back



=head2 KBparallelstatusOutputObj

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
num_jobs_checked has a value which is an int
jobstatus has a value which is a reference to a list where each element is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
num_jobs_checked has a value which is an int
jobstatus has a value which is a reference to a list where each element is a string


=end text

=back



=head2 KBparallelcancel_runInput

=over 4



=item Description

cancel_run() method


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 KBparallelcancel_runOutput

=over 4



=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 KBparallelgetlogInput

=over 4



=item Description

getlog() method


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 KBparallelgetlogOutput

=over 4



=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=cut

package KBparallel::KBparallelClient::RpcClient;
use base 'JSON::RPC::Client';
use POSIX;
use strict;

#
# Override JSON::RPC::Client::call because it doesn't handle error returns properly.
#

sub call {
    my ($self, $uri, $headers, $obj) = @_;
    my $result;


    {
	if ($uri =~ /\?/) {
	    $result = $self->_get($uri);
	}
	else {
	    Carp::croak "not hashref." unless (ref $obj eq 'HASH');
	    $result = $self->_post($uri, $headers, $obj);
	}

    }

    my $service = $obj->{method} =~ /^system\./ if ( $obj );

    $self->status_line($result->status_line);

    if ($result->is_success) {

        return unless($result->content); # notification?

        if ($service) {
            return JSON::RPC::ServiceObject->new($result, $self->json);
        }

        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    elsif ($result->content_type eq 'application/json')
    {
        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    else {
        return;
    }
}


sub _post {
    my ($self, $uri, $headers, $obj) = @_;
    my $json = $self->json;

    $obj->{version} ||= $self->{version} || '1.1';

    if ($obj->{version} eq '1.0') {
        delete $obj->{version};
        if (exists $obj->{id}) {
            $self->id($obj->{id}) if ($obj->{id}); # if undef, it is notification.
        }
        else {
            $obj->{id} = $self->id || ($self->id('JSON::RPC::Client'));
        }
    }
    else {
        # $obj->{id} = $self->id if (defined $self->id);
	# Assign a random number to the id if one hasn't been set
	$obj->{id} = (defined $self->id) ? $self->id : substr(rand(),2);
    }

    my $content = $json->encode($obj);

    $self->ua->post(
        $uri,
        Content_Type   => $self->{content_type},
        Content        => $content,
        Accept         => 'application/json',
	@$headers,
	($self->{token} ? (Authorization => $self->{token}) : ()),
    );
}



1;