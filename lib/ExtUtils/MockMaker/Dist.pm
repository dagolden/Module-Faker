package ExtUtils::MockMaker::Dist;
use Moose;

use ExtUtils::MockMaker::Package;
use ExtUtils::MockMaker::Module;

use Archive::Any::Create;
use File::Temp ();

has name         => (is => 'ro', isa => 'Str', required => 1);
has version      => (is => 'ro', isa => 'Maybe[Str]', default => '0.01');
has archive_ext  => (is => 'ro', isa => 'Str', default => 'tar.gz');

has archive_basename => (
  is   => 'ro',
  isa  => 'Str',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    return sprintf '%s-%s', $self->name, $self->version // 'undef';
  },
);

sub __dist_to_pkg { my $str = shift; $str =~ s/-/::/g; return $str; }
sub __pkg_to_file { my $str = shift; $str =~ s{::}{/}g; return "lib/$str.pm"; }

has provides => (
  is     => 'ro',
  isa    => 'ExtUtils::MockMaker::Type::Packages',
  lazy   => 1,
  coerce => 1,
  required   => 1,
  default    => sub {
    my ($self) = @_;
    my $pkg = __dist_to_pkg($self->name);
    return [
      ExtUtils::MockMaker::Package->new({
        name    => $pkg,
        version => $self->version,
        in_file => __pkg_to_file($pkg),
      })
    ]
  },
  auto_deref => 1,
);

sub modules {
  my ($self) = @_;

  my %module;
  for my $pkg ($self->provides) {
    my $filename = $pkg->in_file;

    push @{ $module{ $filename } ||= [] }, $pkg;
  }

  my @modules = map {
    ExtUtils::MockMaker::Module->new({
      packages => $module{$_},
      filename => $_,
    });
  } keys %module;

  return @modules;
}

sub make_dist {
  my ($self, $arg) = @_;
  $arg ||= {};

  my $dir = $arg->{dir} || File::Temp::tempdir;

  my $archive   = Archive::Any::Create->new;
  my $container = $self->archive_basename;
  my $ext       = $self->archive_ext;

  $archive->container($container);

  for my $file ($self->modules) {
    $archive->add_file($file->filename, $file->as_string);
  }

  my $archive_filename = File::Spec->catfile($dir, "$container.$ext");
  $archive->write_file($archive_filename);

  return $archive_filename;
}

1;