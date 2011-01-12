package WormBase::Schema::Result::Page;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

WormBase::Schema::Result::Issue

=cut

__PACKAGE__->table("pages");

__PACKAGE__->add_columns(
  "page_id",
  { data_type => "integer", is_nullable => 0 },
   "url",
  { data_type => "char(72)", is_nullable => 0 },
  "title",
  { data_type => "text", is_nullable => 1 },
  "is_obj",
  { data_type => "bool", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("page_id");


#__PACKAGE__->add_unique_constraint([ 'openid_url' ]);
__PACKAGE__->has_many(user_saved=>'WormBase::Schema::Result::UserSave', 'page_id');

__PACKAGE__->many_to_many(visits=>'user_history', 'visits');
__PACKAGE__->many_to_many(user_history=>'WormBase::Schema::Result::UserHistory', 'page_id');

1;