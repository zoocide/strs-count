#!/usr/bin/perl -w
use strict;
use FileHandle;
use CmdArgs;

my $gl_lang;
my $verbose;

my $args = CmdArgs->declare(
  '1.0',
  use_cases => [
    main => ['OPTIONS files:...', 'Script counts statistics for the specified source files.'],
  ],
  options => {
    c_lang => ['-c', 'Treat all files as they are written in C.', sub { $gl_lang = 'c' }],
    fort_fixed_lang => ['-ffixed', 'Treat all files as they are written in Fortran fixed format.',
                        sub { $gl_lang = 'fortran::fixed' }],
    fort_free_lang => ['-ffree', 'Treat all files as they are written in Fortran free format.',
                        sub { $gl_lang = 'fortran::free' }],
    verbose => ['-v', 'Print information for each file.', \$verbose],
  },
  restrictions => [
    'c_lang|fort_fixed_lang|fort_free_lang'
  ],
);
$args->parse;

my $st_uchars = 0;
my $st_ulines = 0;
my $st_tlines = 0;
my $st_skspaces = 0;
my $st_skcoms = 0;

my @files = map glob($_), @{$args->arg('files')};
for my $fname (@files){
  my $lang = $gl_lang;

  if (!$lang){
    if ($fname =~ /\.(f|for|fpp|ftn|fdv)$/i){
      $lang = 'fortran::fixed';
    }
    elsif ($fname =~ /\.(f90|f95|f03|f08)$/i){
      $lang = 'fortran::free';
    }
    elsif ($fname =~ /\.(c|cdv|h|cpp)$/i){
      $lang = 'c';
    }
    else {
      die "ERROR: Cannot determine language for file '$fname'.".
          " You should specify language (C or Fortran).\n";
    }
  }

  my $chars = 0;
  my $lines = 0;
  my $pline = 0;
  my $lexer = "lexer::$lang"->new($fname);
  while (defined ($_ = $lexer->get_word)){
    #print "word #$_#\n";
    $chars += length $_;
    my $l = $lexer->current_line;
    $lines ++ if $l != $pline;
    $pline = $l;
  }

  my ($uc, $ul, $tl, $ss, $sc);
  $st_uchars += $uc = $chars;
  $st_ulines += $ul = $lines;
  $st_tlines += $tl = $lexer->current_line - ($lexer->current_column > 1 ? 0 : 1);
  $st_skspaces += $ss = $lexer->skipped_space_chars;
  $st_skcoms += $sc = $lexer->skipped_comments_chars;
  if ($verbose){
    format STDOUT_TOP =
  file format        uc       ul       tl       ss       sc   filename
.
    format STDOUT =
@|||||||||||||| @####### @####### @####### @####### @####### @*
    $lang,       $uc,     $ul,     $tl,     $ss,     $sc,     $fname
.
    #print("$lang $uc $ul $tl $ss $sc\t$fname\n");
    write;
  }
}

print "useful characters number = $st_uchars\n";
print "useful lines number = $st_ulines\n";
print "total lines number = $st_tlines\n";
print "skipped space characters number = $st_skspaces\n";
print "skipped comments characters number = $st_skcoms\n";


package lexer;

sub new
{
  my $class = shift;
  my $self = bless {}, $class;
  $self->m_init(@_);
  $self
}

sub current_line { $_[0]{line} }
sub current_column { $_[0]{column} }
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
  $self->{column} = 1;
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
  $_[0]{space_chars} += $ret;
  $_[0]{column} += $ret;
  $ret
}

sub m_skip_newline
{
  return 0 unless $_[0]->m_buf =~ s/^\r?\n//;
  $_[0]{line}++;
  $_[0]{column} = 1;
  1
}

sub m_cut_buf
{
  my $ret = $_[0]{buf};
  $_[0]{buf} = '';
  $_[0]{line}++;
  $_[0]{column} = 1;
  $ret
}

sub m_get_string
{
  my $ret;
  if ($_[0]->m_buf =~ s/^('|")//){
    my $b = $1;
    $_[0]{column} += length $1;
    $ret = $b;
    while ($_[0]->m_buf){
      if ($_[0]{buf} =~ s/^(([^$b\\]|\\.)*$b)//){
        $ret .= $1;
        $_[0]{column} += length $1;
        last;
      }
      $ret .= $_[0]->m_cut_buf;
    }
  }
  $ret
}

sub m_get_word
{
  $_[0]{column} += length $1 if $_[0]->m_buf =~ s/^(.\w*)//;
  $1
}

package lexer::c;
use base qw(lexer);

sub m_skip_comments
{
  return '' if !$_[0]{skip_comments};
  my $com = '';
  if ($_[0]->m_buf =~ s#^(//.*)##){
    ## single line comments // ##
    $_[0]{column} += length $1;
    $com .= $1;
    while ($com =~ /\\$/){
      $_[0]->m_skip_newline;
      last if !$_[0]->m_buf;
      $_[0]{buf} =~ s/^(.*)//;
      $_[0]{column} += length $1;
      $com .= "\n".$1;
    }
  }
  elsif ($_[0]{buf} =~ s#^(/\*)##){
    ## multiline comments /**/ ##
    $com .= $1;
    $_[0]{column} += length $1;
    while ($_[0]->m_buf){
      if ($_[0]{buf} =~ s#^(([^\\]|\\.)*\*/)##){
        $com .= $1;
        $_[0]{column} += length $1;
        last;
      }
      $com .= $_[0]->m_cut_buf;
    }
  }
  #print "comments: |$_|\n" for split /\n/, $com;
  $_[0]{comments_chars} += length $com;
  $com
}

package lexer::fortran::fixed;
use base qw(lexer);

sub m_read_line
{
  my $f = $_[0]{file};
  my $l = <$f>;
  return 0 unless defined $l;
  if (length $l > 72){
    $_[0]{comments_chars} += length($l) - 72;
    #print "comments: ", substr($l, 72), "\n";
    $l = substr($l, 0, 72)."\n";
  }
  $_[0]{buf} .= $l;
  1
}

sub m_skip_comments
{
  return '' if !$_[0]{skip_comments};
  my $com = '';
  ## do not skip pragmas ##
  return '' if $_[0]{column} == 1 && $_[0]->m_buf =~ /^(c|\*|!)(dvm\$|\$omp)/i;

  if ($_[0]{column} == 1 && $_[0]->m_buf =~ s#^((c|\*).*)##i){
    ## line comments C/* ##
    $com .= $1;
    $_[0]{column} += length $1;
  }
  elsif ($_[0]->m_buf =~ s#^(!.*)##){
    ## line comments ! ##
    $com .= $1;
    $_[0]{column} += length $1;
  }
  #print "comments: |$_|\n" for split /\n/, $com;
  $_[0]{comments_chars} += length $com;
  $com
}

package lexer::fortran::free;
use base qw(lexer);

sub m_skip_comments
{
  return '' if !$_[0]{skip_comments};
  my $com = '';
  ## do not skip pragmas ##
  return '' if $_[0]->m_buf =~ /^!(dvm\$|\$omp)/i;

  if ($_[0]->m_buf =~ s#^(!.*)##){
    ## line comments ! ##
    $com .= $1;
    $_[0]{column} += length $1;
  }
  #print "comments: |$_|\n" for split /\n/, $com;
  $_[0]{comments_chars} += length $com;
  $com
}
