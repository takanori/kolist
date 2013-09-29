package KoList::Web;

use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Kossy;
use KoList::Model;
use Plack::Session;
use DateTime;
use JSON qw/encode_json decode_json/;
use Data::GUID::URLSafe;
use Digest::SHA;
use Config::Simple;

#======================================================================== 
# Route ================================================================= 
#======================================================================== 

filter 'set_title' => sub {
	my $app = shift;
	sub {
		my ( $self, $c )  = @_;
		$c->stash->{site_name} = __PACKAGE__;
		$app->($self,$c);
	}
};

filter 'stash_login_condition' => sub {
	my $app = shift;
	sub {
		my ( $self, $c )  = @_;
		my $session = Plack::Session->new($c->req->env);

		if ($session->get('user_id')) {
			$c->stash->{logged_in} = 1;
		}
		$c->stash->{loggedIn} = 1;
		$app->($self,$c);
	}
};

filter 'logged_in_only' => sub {
	my $app = shift;
	sub {
		my ($self, $c) = @_;
		my $session = Plack::Session->new($c->req->env);

		if (!$session->get('user_id')) {
			return;
			# return $c->redirect('/login'); 
		}
		$c->stash->{logged_in} = 1;
		return $app->($self, $c);
	}
};

get '/' => [qw/set_title stash_login_condition/] => sub {
	my ( $self, $c )  = @_;

	my $session = Plack::Session->new($c->req->env);
	$c->render('index.tx', { tmp => $session->id });
	# $c->render('index.tx', {});
};

# Todo ================================================================== 

get '/todos' => [qw/logged_in_only/] => sub {
	my ($self, $c) = @_;
	$c->render('todos.tx', {});
};

# TODO make CRUS ad logged_in_only
post '/todos/create' => sub {
	my ($self, $c) = @_;
	my $result = $c->req->validator([
			'text' => {
				rule => [
					['NOT_NULL', 'text is null'],
				],
			},
		]);
	if ($result->has_error) {
		my $error_messages = [$result->errors->{text}];
		return $c->render_json({error_messages => $error_messages});
	}
	my $todo = $self->create_todo($result->valid('text'));
	$c->render_json({todo => $todo});
};

get '/todos/search' => sub {
	my ($self, $c) = @_;
	my $todos = $self->todo_list;
	$c->render_json({todos => $todos});
};

router 'PUT' => '/todos/update' => sub {
	my ($self, $c) = @_;
	my $result = $c->req->validator([
			'text' => {
				rule => [
					['NOT_NULL', 'text is null'],
				],
			},
		]);
	if ($result->has_error) {
		my $error_messages = [$result->errors->{text}];
		return $c->render_json({ error_messages => $error_messages });
	}

	my $todo = $self->update_todo($c->req->param('todo_id'), $result->valid('text'));
	$c->render_json({todo => $todo});
};

router 'DELETE' => '/todos/delete' => sub {
	my ($self, $c) = @_;
	my $todo_id = $c->req->param('todo_id');
	my $deleted_rows_count = $self->delete_todo($todo_id);
	if ($deleted_rows_count != 1) {
		my $error_messages = ['$deleted_rows_count is ' . $deleted_rows_count];
		return $c->render_json({todo_id => $todo_id, error_messages => $error_messages});
	} else {
		return $c->render_json({todo_id => $todo_id});
	}
};

# Register ================================================================== 

get '/register' => sub {
	my ($self, $c) = @_;
	$c->render('register.tx', {});
};

post '/register/create' => sub {
	my ($self, $c) = @_;
	my $username = $c->req->param('username');
	my $email = $c->req->param('email');
	my $password = $c->req->param('password');

	my $user_id = $self->create_user($username, $email, $password);

	my $session = Plack::Session->new($c->req->env);
	$session->set('user_id', $user_id);
	$session->set('username', $username);
	$c->redirect('/todos'); 
};

post '/register/validate' => sub {
	my ($self, $c) = @_;
	my $username = $c->req->param('username');

	if ($self->username_exists($username)) {
		$c->render_json(JSON::false);
	} else {
		$c->render_json(JSON::true);
	}
};

# Login ===================================================================== 

get '/login' => sub {
	my ($self, $c) = @_;
	$c->render('login.tx', {});
};

post '/login/validate' => sub {
	my ($self, $c) = @_;
	my $username = $c->req->param('username');
	my $password = $c->req->param('password');

	my $user_id = $self->check_username_and_password($username, $password);
	if (!$user_id) {
		return $c->render_json(JSON::false);
	}

	my $session = Plack::Session->new($c->req->env);
	$session->set('user_id', $user_id);
	$session->set('username', $username);

	return $c->render_json(JSON::true);
};

# Use 'get' just for convenience
get '/logout' => sub {
	my ($self, $c) = @_;
	my $session = Plack::Session->new($c->req->env);
	$session->expire;
	$c->redirect('/');
};

#======================================================================== 
# Function ============================================================== 
#======================================================================== 

sub db {
	my $self = shift;
	
	if (!defined($self->{_db})) {
		my $config = new Config::Simple('config.pm');
		my $cfg = $config->vars();
		$self->{_db} = KossyAdvance::Model->new(connect_info => [
			$cfg->{'mysql.dsn'},
			$cfg->{'mysql.user'},
			$cfg->{'mysql.pass'},
			{ mysql_enable_utf8 => 1 },
		]);
	}
	$self->{_db};
}

# Todos ================================================================== 

sub create_todo {
	my ($self, $text) = @_;
	$text = "" if !defined $text;
	my $row = $self->db->insert('todos', {
			text => $text,
			created_at => $self->current_time,
		});
	return \%{$row->get_columns};
}

sub todo_list {
	my $self = shift;
	my $itr = $self->db->search('todos', {}, {
			order_by => {'id' => 'DESC'},
		});

	my @rows;
	while (my $row = $itr->next) {
		push(@rows, $row->get_columns);
	}
	return \@rows;
}

sub update_todo {
	my ($self, $todo_id, $text) = @_;
	$text = '' if !defined $text;
	my $update_row_count = $self->db->update('todos',
		{
			text => $text,
		},
		{
			id => $todo_id,
		},
	);
	my $row = $self->db->single('todos', {
			id => $todo_id,
		});
	return \%{$row->get_columns};
}

sub delete_todo {
	my ($self, $todo_id) = @_;
	if (!defined($todo_id)) {
		return -1;
	}
	my $deleted_rows_count = $self->db->delete('todos', {
			id => $todo_id,
		});
	return $deleted_rows_count;
}

# Users ================================================================== 

sub username_exists {
	my ($self, $username) = @_;

	my $row = $self->db->single('users', {
			user_name => $username,
		});
	return $row ? 1 : 0;
}

sub check_username_and_password {
	my ($self, $username, $password) = @_;

	my $row = $self->db->single('users', {
			user_name => $username,
			password => Digest::SHA::sha1_hex($username . $password),
		});

	return $row ? $row->get_column('user_id') : 0;
}

sub create_user {
	my ($self, $username, $email, $password) = @_;

	my $row = $self->db->insert('users', {
			user_id => Data::GUID->new->as_base64_urlsafe,
			user_name => $username,
			email => $email,
			password => Digest::SHA::sha1_hex($username . $password),
			created_at => $self->current_time,
		});

	return $row->get_column('user_id');
}

# Utility ================================================================== 

sub current_time {
	my ($self) = @_;
	return DateTime->now(time_zone => 'Asia/Tokyo');
}

1;

