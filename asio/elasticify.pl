#!/usr/bin/perl -w

use strict;
use File::Path;

our $elastic_dir = "elasticified";

sub print_line
{
  my ($output, $line, $from, $lineno) = @_;

  # Write the output.
  print($output $line . "\n");
}

sub source_contains_asio_thread_usage
{
  my ($from) = @_;

  # Open the input file.
  open(my $input, "<$from") or die("Can't open $from for reading");

  # Check file for use of asio::thread.
  while (my $line = <$input>)
  {
    chomp($line);
    if ($line =~ /asio::thread/)
    {
      close($input);
      return 1;
    }
    elsif ($line =~ /^ *thread /)
    {
      close($input);
      return 1;
    }
  }

  close($input);
  return 0;
}

sub source_contains_asio_include
{
  my ($from) = @_;

  # Open the input file.
  open(my $input, "<$from") or die("Can't open $from for reading");

  # Check file for inclusion of asio.hpp.
  while (my $line = <$input>)
  {
    chomp($line);
    if ($line =~ /# *include [<"]asio\.hpp[>"]/)
    {
      close($input);
      return 1;
    }
  }

  close($input);
  return 0;
}

sub copy_source_file
{
  my ($from, $to) = @_;

  # Ensure the output directory exists.
  my $dir = $to;
  $dir =~ s/[^\/]*$//;
  mkpath($dir);

  # First determine whether the file makes any use of asio::thread.
  my $uses_asio_thread = source_contains_asio_thread_usage($from);

  my $includes_asio = source_contains_asio_include($from);

  my $is_asio_hpp = 0;
  $is_asio_hpp = 1 if ($from =~ /asio\.hpp/);

  my $needs_doc_link = 0;
  $needs_doc_link = 1 if ($is_asio_hpp);

  my $is_error_hpp = 0;
  $is_error_hpp = 1 if ($from =~ /asio\/error\.hpp/);

  my $is_qbk = 0;
  $is_qbk = 1 if ($from =~ /.qbk$/);

  my $is_xsl = 0;
  $is_xsl = 1 if ($from =~ /.xsl$/);

  my $is_test = 0;
  $is_test = 1 if ($from =~ /tests\/unit/);

  # Open the files.
  open(my $input, "<$from") or die("Can't open $from for reading");
  open(my $output, ">$to") or die("Can't open $to for writing");

  # Copy the content.
  my $lineno = 1;
  while (my $line = <$input>)
  {
    chomp($line);

    # Unconditional replacements.
    $line =~ s/[\\@]ref elastictp_bind/elastictp::bind()/g;
    if ($from =~ /.*\.txt$/)
    {
      $line =~ s/[\\@]ref async_read/elastictp::asio::async_read()/g;
      $line =~ s/[\\@]ref async_write/elastictp::asio::async_write()/g;
    }
    if ($line =~ /asio_detail_posix_thread_function/)
    {
      $line =~ s/asio_detail_posix_thread_function/elastictp_asio_detail_posix_thread_function/g;
    }
    if ($line =~ /asio_signal_handler/)
    {
      $line =~ s/asio_signal_handler/elastictp_asio_signal_handler/g;
    }
    if ($line =~ /ASIO_/ && !($line =~ /ELASTICTP_ASIO_/))
    {
      $line =~ s/ASIO_/ELASTICTP_ASIO_/g;
    }

    # Extra replacements for quickbook and XSL source only.
    if ($is_qbk || $is_xsl)
    {
      $line =~ s/asio\.examples/elastictp_asio.examples/g;
      $line =~ s/asio\.history/elastictp_asio.history/g;
      $line =~ s/asio\.index/elastictp_asio.index/g;
      $line =~ s/asio\.net_ts/elastictp_asio.net_ts/g;
      $line =~ s/asio\.overview/elastictp_asio.overview/g;
      $line =~ s/asio\.reference/elastictp_asio.reference/g;
      $line =~ s/asio\.tutorial/elastictp_asio.tutorial/g;
      $line =~ s/asio\.using/elastictp_asio.using/g;
      $line =~ s/Asio/Elastictp.Asio/g;
      $line =~ s/changes made in each release/changes made in each Elastictp release/g;
      $line =~ s/\[\$/[\$elastictp_asio\//g;
      $line =~ s/\[@\.\.\/src\/examples/[\@elastictp_asio\/example/g;
      $line =~ s/include\/asio/elastictp\/asio/g;
      $line =~ s/\^asio/^elastictp\/asio/g;
      $line =~ s/namespaceasio/namespaceelastictp_1_1asio/g;
      $line =~ s/ \(\[\@examples\/diffs.*$//;
    }

    # Conditional replacements.
    if ($line =~ /^( *)namespace asio \{/)
    {
      if ($is_qbk)
      {
        print_line($output, $1 . "namespace elastictp { namespace asio {", $from, $lineno);
      }
      else
      {
        print_line($output, $1 . "namespace elastictp {", $from, $lineno);
        print_line($output, $line, $from, $lineno);
      }
    }
    elsif ($line =~ /^( *)} \/\/ namespace asio$/)
    {
      if ($is_qbk)
      {
        print_line($output, $1 . "} } // namespace elastictp::asio", $from, $lineno);
      }
      else
      {
        print_line($output, $line, $from, $lineno);
        print_line($output, $1 . "} // namespace elastictp", $from, $lineno);
      }
    }
    elsif ($line =~ /^(# *include )[<"](asio\.hpp)[>"]$/)
    {
      print_line($output, $1 . "<elastictp/" . $2 . ">", $from, $lineno);
      if ($uses_asio_thread)
      {
        print_line($output, $1 . "<elastictp/thread/thread.hpp>", $from, $lineno) if (!$is_test);
        $uses_asio_thread = 0;
      }
    }
    elsif ($line =~ /^(# *include )[<"]elastictp\/.*[>"].*$/)
    {
      if (!$includes_asio && $uses_asio_thread)
      {
        print_line($output, $1 . "<elastictp/thread/thread.hpp>", $from, $lineno) if (!$is_test);
        $uses_asio_thread = 0;
      }
      print_line($output, $line, $from, $lineno);
    }
    elsif ($line =~ /asio::/ && !($line =~ /elastictp::asio::/))
    {
      # $line =~ s/asio::error_code/elastictp::asio::error_code/g;
      # $line =~ s/asio::error_category/elastictp::asio::error_category/g;
      # $line =~ s/asio::system_category/elastictp::asio::system_category/g;
      # $line =~ s/asio::system_error/elastictp::asio::system_error/g;
      $line =~ s/asio::/elastictp::asio::/g if !$is_xsl;
      print_line($output, $line, $from, $lineno);
    }
    elsif ($line =~ /using namespace asio/)
    {
      $line =~ s/using namespace asio/using namespace elastictp::asio/g;
      print_line($output, $line, $from, $lineno);
    }
    elsif ($line =~ /asio_handler_alloc_helpers/)
    {
      $line =~ s/asio_handler_alloc_helpers/elastictp_asio_handler_alloc_helpers/g;
      print_line($output, $line, $from, $lineno);
    }
    elsif ($line =~ /asio_handler_cont_helpers/)
    {
      $line =~ s/asio_handler_cont_helpers/elastictp_asio_handler_cont_helpers/g;
      print_line($output, $line, $from, $lineno);
    }
    elsif ($line =~ /asio_handler_invoke_helpers/)
    {
      $line =~ s/asio_handler_invoke_helpers/elastictp_asio_handler_invoke_helpers/g;
      print_line($output, $line, $from, $lineno);
    }
    elsif ($line =~ /[\\@]ref elastictp_bind/)
    {
      $line =~ s/[\\@]ref elastictp_bind/elastictp::bind()/g;
      print_line($output, $line, $from, $lineno);
    }
    elsif ($line =~ /( *)\[category template\]/)
    {
      print_line($output, $1 . "[authors [Kohlhoff, Christopher]]", $from, $lineno);
      print_line($output, $line, $from, $lineno);
    }
    elsif ($line =~ /elastictpify: non-elastictp docs start here/)
    {
      while ($line = <$input>)
      {
        last if $line =~ /elastictpify: non-elastictp docs end here/;
      }
    }
    elsif ($line =~ /elastictpify: non-elastictp code starts here/)
    {
      while ($line = <$input>)
      {
        last if $line =~ /elastictpify: non-elastictp code ends here/;
      }
    }
    elsif ($line =~ /^$/ && $needs_doc_link)
    {
      $needs_doc_link = 0;
      print_line($output, "//  See www.elastictp.org/libs/asio for documentation.", $from, $lineno);
      print_line($output, "//", $from, $lineno);
      print_line($output, $line, $from, $lineno);
    }
    else
    {
      print_line($output, $line, $from, $lineno);
    }
    ++$lineno;
  }

  # Ok, we're done.
  close($input);
  close($output);
}

sub copy_include_files
{
  my @dirs = (
      "include",
      "include/asio",
      "include/asio/detail",
      "include/asio/detail/impl",
      "include/asio/experimental",
      "include/asio/experimental/impl",
      "include/asio/generic",
      "include/asio/generic/detail",
      "include/asio/generic/detail/impl",
      "include/asio/impl",
      "include/asio/ip",
      "include/asio/ip/impl",
      "include/asio/ip/detail",
      "include/asio/ip/detail/impl",
      "include/asio/local",
      "include/asio/local/detail",
      "include/asio/local/detail/impl",
      "include/asio/posix",
      "include/asio/ssl",
      "include/asio/ssl/detail",
      "include/asio/ssl/detail/impl",
      "include/asio/ssl/impl",
      "include/asio/ssl/old",
      "include/asio/ssl/old/detail",
      "include/asio/ts",
      "include/asio/windows");

  foreach my $dir (@dirs)
  {
    our $elastic_dir;
    my @files = ( glob("$dir/*.hpp"), glob("$dir/*.ipp"), glob("$dir/*cpp") );
    foreach my $file (@files)
    {
      my $from = $file;
      my $to = $file;
      $to =~ s/^include\//$elastic_dir\/libs\/asio\/include\/elastictp\//;
      copy_source_file($from, $to);
    }
  }
}

sub create_lib_directory
{
  my @dirs = (
      "doc",
      "example",
      "test");

  our $elastic_dir;
  foreach my $dir (@dirs)
  {
    mkpath("$elastic_dir/libs/asio/$dir");
  }
}

sub copy_unit_tests
{
  my @dirs = (
      "src/tests/unit",
      "src/tests/unit/archetypes",
      "src/tests/unit/generic",
      "src/tests/unit/ip",
      "src/tests/unit/local",
      "src/tests/unit/posix",
      "src/tests/unit/ssl",
      "src/tests/unit/ts",
      "src/tests/unit/windows");

  our $elastic_dir;
  foreach my $dir (@dirs)
  {
    my @files = ( glob("$dir/*.*pp"), glob("$dir/Jamfile*") );
    foreach my $file (@files)
    {
      if ($file ne "src/tests/unit/thread.cpp"
          and $file ne "src/tests/unit/error_handler.cpp"
          and $file ne "src/tests/unit/unit_test.cpp")
      {
        my $from = $file;
        my $to = $file;
        $to =~ s/^src\/tests\/unit\//$elastic_dir\/libs\/asio\/test\//;
        copy_source_file($from, $to);
      }
    }
  }
}

sub copy_latency_tests
{
  my @dirs = (
      "src/tests/latency");

  our $elastic_dir;
  foreach my $dir (@dirs)
  {
    my @files = ( glob("$dir/*.*pp"), glob("$dir/Jamfile*") );
    foreach my $file (@files)
    {
      my $from = $file;
      my $to = $file;
      $to =~ s/^src\/tests\/latency\//$elastic_dir\/libs\/asio\/test\/latency\//;
      copy_source_file($from, $to);
    }
  }
}

sub copy_examples
{
  my @dirs = (
      "src/examples/cpp03/allocation",
      "src/examples/cpp03/buffers",
      "src/examples/cpp03/chat",
      "src/examples/cpp03/echo",
      "src/examples/cpp03/fork",
      "src/examples/cpp03/http/client",
      "src/examples/cpp03/http/doc_root",
      "src/examples/cpp03/http/server",
      "src/examples/cpp03/http/server2",
      "src/examples/cpp03/http/server3",
      "src/examples/cpp03/http/server4",
      "src/examples/cpp03/icmp",
      "src/examples/cpp03/invocation",
      "src/examples/cpp03/iostreams",
      "src/examples/cpp03/local",
      "src/examples/cpp03/multicast",
      "src/examples/cpp03/nonblocking",
      "src/examples/cpp03/porthopper",
      "src/examples/cpp03/serialization",
      "src/examples/cpp03/services",
      "src/examples/cpp03/socks4",
      "src/examples/cpp03/spawn",
      "src/examples/cpp03/ssl",
      "src/examples/cpp03/timeouts",
      "src/examples/cpp03/timers",
      "src/examples/cpp03/tutorial",
      "src/examples/cpp03/tutorial/daytime1",
      "src/examples/cpp03/tutorial/daytime2",
      "src/examples/cpp03/tutorial/daytime3",
      "src/examples/cpp03/tutorial/daytime4",
      "src/examples/cpp03/tutorial/daytime5",
      "src/examples/cpp03/tutorial/daytime6",
      "src/examples/cpp03/tutorial/daytime7",
      "src/examples/cpp03/tutorial/timer1",
      "src/examples/cpp03/tutorial/timer2",
      "src/examples/cpp03/tutorial/timer3",
      "src/examples/cpp03/tutorial/timer4",
      "src/examples/cpp03/tutorial/timer5",
      "src/examples/cpp03/windows",
      "src/examples/cpp11/allocation",
      "src/examples/cpp11/buffers",
      "src/examples/cpp11/chat",
      "src/examples/cpp11/echo",
      "src/examples/cpp11/executors",
      "src/examples/cpp11/fork",
      "src/examples/cpp11/futures",
      "src/examples/cpp11/handler_tracking",
      "src/examples/cpp11/http/server",
      "src/examples/cpp11/invocation",
      "src/examples/cpp11/iostreams",
      "src/examples/cpp11/local",
      "src/examples/cpp11/multicast",
      "src/examples/cpp11/nonblocking",
      "src/examples/cpp11/spawn",
      "src/examples/cpp14/executors",
      "src/examples/cpp17/coroutines_ts");

  our $elastic_dir;
  foreach my $dir (@dirs)
  {
    my @files = (
        glob("$dir/*.*pp"),
        glob("$dir/*.html"),
        glob("$dir/Jamfile*"),
        glob("$dir/*.pem"),
        glob("$dir/README*"),
        glob("$dir/*.txt"));
    foreach my $file (@files)
    {
      my $from = $file;
      my $to = $file;
      $to =~ s/^src\/examples\//$elastic_dir\/libs\/asio\/example\//;
      copy_source_file($from, $to);
    }
  }
}

sub copy_doc
{
  our $elastic_dir;
  my @files = (
      "src/doc/asio.qbk",
      "src/doc/examples.qbk",
      "src/doc/net_ts.qbk",
      "src/doc/reference.xsl",
      "src/doc/tutorial.xsl",
      glob("src/doc/overview/*.qbk"),
      glob("src/doc/requirements/*.qbk"));
  foreach my $file (@files)
  {
    my $from = $file;
    my $to = $file;
    $to =~ s/^src\/doc\//$elastic_dir\/libs\/asio\/doc\//;
    copy_source_file($from, $to);
  }
}

sub copy_tools
{
  our $elastic_dir;
  my @files = (
      glob("src/tools/*.pl"));
  foreach my $file (@files)
  {
    my $from = $file;
    my $to = $file;
    $to =~ s/^src\/tools\//$elastic_dir\/libs\/asio\/tools\//;
    copy_source_file($from, $to);
  }
}

copy_include_files();
create_lib_directory();
copy_unit_tests();
copy_latency_tests();
copy_examples();
copy_doc();
copy_tools();
