#!/usr/bin/env perl

use Carp;
use HTML::TokeParser;
use URI;
use LWP::UserAgent;
use MIME::Lite;
use Modern::Perl;
use Readonly;

Readonly my $base => q(http://www.apress.com);
Readonly my $site => URI->new_abs('/info/dailydeal', $base);
Readonly my $email => q{matt.p.foster@gmail.com};
Readonly my $subject => q{Apress Book of the Day};

# Tokenise the page, and extract book details.
sub process_page {
    my $content = shift || croak "No page content supplied";    
    my $stream = HTML::TokeParser->new( \$content );
    while(my $token = $stream->get_token) { 
        # Find <div class = 'bookdetails'>
        if ($token->[0] eq 'S'   and
            $token->[1] eq 'div' and
            ($token->[2]{'class'} || 0) eq 'bookdetails') {
            # If we see the right things, the next A tag has a link to the book.
            my(@next) = $stream->get_tag('a');
            push @next, $stream->get_token;
            email_info(@next);
            last;
        }
    }    
}

# Format the Book information.
sub format_info {
    my @info = @_;
    my %book_info;
    $book_info{'book'} = $info[1][1];
    $book_info{'link'} = URI->new_abs($info[0][1]{'href'}, $base);
    return %book_info;
}

# Create and send an email.
sub email_info {    
    my @info = @_;
    # Format the info.
    my %info = format_info(@info);
    # Generate a simple email.
    my $msg = MIME::Lite->new(
        From     => $email,
        To       => $email,
        Subject  => $subject . ": $info{'book'}",
        Data     => qq{$subject: $info{'book'}\nAvailable from: $info{'link'}},
    );
    # Send it.
    $msg->send || croak "Could not send email";
}

MAIN: {
    # Grab the page, and pass process it with HTML::TokeParser
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;

    my $response = $ua->get($site);

    if ($response->is_success) {
        process_page($response->decoded_content, $base);
    }
    else {
        croak $response->status_line;
    }    
}


