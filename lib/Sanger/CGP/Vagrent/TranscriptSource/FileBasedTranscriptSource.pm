package Sanger::CGP::Vagrent::TranscriptSource::FileBasedTranscriptSource;

use strict;

use Carp;
use Log::Log4perl;
use Data::Dumper;
use Const::Fast qw(const);

use Bio::DB::Sam;

use Tabix;

use Sanger::CGP::Vagrent::Data::Transcript;
use Sanger::CGP::Vagrent::Data::Exon;

use base qw(Sanger::CGP::Vagrent::TranscriptSource::AbstractTranscriptSource);

my $log = Log::Log4perl->get_logger(__PACKAGE__);

const my $SEARCH_BUFFER => 10000;

1;

sub getTranscripts {
  my ($self,$gp) = @_;
  unless(defined($gp) && $gp->isa('Sanger::CGP::Vagrent::Data::AbstractGenomicPosition')){
    $log->error("Did not recieve a Sanger::CGP::Vagrent::Data::AbstractGenomicPosition object");
    return undef;
  }
  my $trans = $self->_getTranscriptsFromCache($gp);
  return @$trans if defined $trans;
  return;
}


sub _getTranscriptsFromCache {
  my ($self,$gp) = @_;
  $self->{_cache_tbx} = Tabix->new('-data' => $self->{_cache}) unless defined $self->{_cache_tbx};  
  my $min;
  my $max = $gp->getMaxPos + $SEARCH_BUFFER;
  if($gp->getMinPos() < $SEARCH_BUFFER){
    $min = 0;
  } else {
    $min = ($gp->getMinPos - $SEARCH_BUFFER) - 1;
  }
  my $res = $self->{_cache_tbx}->query($gp->getChr(),$min,$max); 
  return undef unless defined $res;
  my $out = undef;
  if(defined $res){
    while(my $ret = $self->{_cache_tbx}->read($res)){
      my $raw = (split("\t",$ret))[6];
      my $VAR1;
      eval $raw;
      $VAR1->{_cdnaseq} = $self->_getTranscriptSeq($VAR1);
      push @$out, $VAR1;
    }
  }
  return $out;
}

sub _init {
	my $self = shift;
  my %vars = @_;
  foreach my $k(keys(%vars)){
    if($k eq 'cache'){
      $self->_setCacheFile($vars{$k});
    }
  }
}

sub _setCacheFile {
  my ($self,$cache) = @_;
  
  unless(-e $cache && -f $cache && -r $cache){
    $log->logcroak("Specified cache file is unreadable: $cache");
  }
  my $cache_index = $cache .".tbi";
  unless(-e $cache_index && -f $cache_index && -r $cache_index){
    $log->logcroak("cache index file is unreadable: $cache_index");
  }
  my $fa = $cache;
  $fa =~ s/\.cache.+$/.fa/;
  unless(-e $fa && -f $fa && -r $fa){
    $log->logcroak("cache fasta file is unreadable: $fa");
  }
  my $fai = $fa . ".fai";
  unless(-e $fai && -f $fai && -r $fai){
    $log->logcroak("cache fasta index file is unreadable: $fai");
  }
  $self->{_cache} = $cache;
  $self->{_cache_fa} = $fa;
}

sub _getTranscriptSeq {
  my ($self,$trans) = @_;
  unless(defined $self->{_fai_obj}){
    $self->{_fai_obj} = Bio::DB::Sam::Fai->load($self->{_cache_fa});
  }
  return $self->{_fai_obj}->fetch($trans->getAccession); 
}