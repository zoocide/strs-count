#!/usr/bin/perl -w
use strict;
use FileHandle;
use CmdArgs;
use CmdArgs::BasicTypes;

my $lang;

my $args = CmdArgs->declare(
  '0.1',
  use_cases => [
    main => ['OPTIONS file:File', 'Script counts statistics for the specified source file.'],
  ],
  options => {
    c_lang => ['-c', 'C language.', sub { $lang = 'c' }],
    fort_lang => ['-f', 'Fortran language.', sub { $lang = 'fortran' }],
  },
  restrictions => [
    'c_lang|fort_lang'
  ],
);
$args->parse;

my $fname = $args->arg('file');

if (!$lang){
  if ($fname =~ /\.(f|f77|f90|for|fdv)$/i){
    $lang = 'fortran';
  }
  elsif ($fname =~ /\.(c|cdv|h|cpp)$/i){
    $lang = 'c';
  }
  else {
    die "ERROR: you should specify language (C or Fortran).\n";
  }
}

my $chars = 0;
my $lines = 0;
my $pline = 0;
my $lexer = "lexer::$lang"->new($fname);
while (defined ($_ = $lexer->get_word)){
  #print "#$_#\n";
  $chars += length $_;
  my $l = $lexer->current_line;
  $lines ++ if $l != $pline;
  $pline = $l;
}

print "useful characters number = $chars\n";
print "useful lines number = $lines\n";
print "total lines number = ", $lexer->current_line, "\n";
print "skipped space characters number = ", $lexer->skipped_space_chars, "\n";
print "skipped comments characters number = ", $lexer->skipped_comments_chars, "\n";



package lexer;

sub new
{
  my $class = shift;
  my $self = bless {}, $class;
  $self->m_init(@_);
  $self
}

sub current_line { $_[0]{line} }
sub skipped_space_chars { $_[0]{space_chars} }
sub skipped_comments_chars { $_[0]{comments_chars} }

sub get_word
{
  my $self = shift;
  1 while $self->m_skip_spaces || $self->m_skip_comments || $self->m_skip_newline;
  $self->m_get_string || $self->m_get_word;
}

sub m_init
{
  my ($self, $fname) = @_;
  $self->{fname} = $fname;
  $self->{file} = FileHandle->new('<'.$fname) or die "can not open file $fname: $!\n";
  $self->{line} = 1;
  $self->{skip_spaces} = 1;
  $self->{skip_comments} = 1;
  $self->{space_chars} = 0;
  $self->{comments_chars} = 0;
}

sub m_read_line
{
  my $self = shift;
  my $f = $self->{file};
  my $l = <$f>;
  if (defined $l){
    $self->{buf} .= $l;
    return 1
  }
  0
}

sub m_buf : lvalue
{
  1 while !$_[0]{buf} && $_[0]->m_read_line;
  $_[0]{buf}
}

sub m_skip_spaces
{
  return 0 if !$_[0]{skip_spaces};
  my $ret = 0;
  $ret += length $1 while $_[0]->m_buf && $_[0]{buf}=~s/^((\t| )+)//;
  $_[0]->{space_chars} += $ret;
  $ret
}

sub m_skip_newline
{
  $_[0]->m_buf =~ s/^\r?\n// ? $_[0]{line}++ : 0
}

sub m_get_string
{
  my $ret;
  if ($_[0]->m_buf =~ s/^('|")//){
    my $b = $1;
    $ret = $b;
    while ($_[0]->m_buf){
      if ($_[0]{buf} =~ s/^(([^$b\\]|\\.)*$b)//){
        $ret .= $1;
        last;
      }
      $ret .= $_[0]{buf};
      $_[0]{buf} = '';
    }
  }
  $ret
}

sub m_get_word
{
  $_[0]->m_buf =~ s/^(.\w*)//;
  $1
}

package lexer::c;
use base qw(lexer);

sub m_skip_comments
{
  return 0 if !$_[0]{skip_comments};
  my $com = '';
  $com .= $1 while $_[0]->m_buf =~ s#^(//.*)##;
  if ($_[0]{buf} && ($_[0]{buf} =~ s#^(/\*)##)){
    $com .= $1;
    while ($_[0]->m_buf){
      if ($_[0]{buf} =~ s#^(([^\\]|\\.)*\*/)##){
        $com .= $1;
        last;
      }
      $com .= $_[0]{buf};
      $_[0]{buf} = '';
      $_[0]{line}++;
    }
  }
  #print "comment: |$_|\n" for split /\n/, $com;
  $_[0]{comments_chars} += length $com;
  $com
}
