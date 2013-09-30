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
			$c->stash->{user_name} = $session->get('user_name');
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
		$c->stash->{user_name} = $session->get('user_name');
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

post '/todos/create' => sub {
	my ($self, $c) = @_;
	# my $result = $c->req->validator([
			# 'content' => {
				# rule => [
					# ['NOT_NULL', 'content is null'],
				# ],
			# },
		# ]);
	# if ($result->has_error) {
		# my $error_messages = [$result->errors->{content}];
		# return $c->render_json({error_messages => $error_messages});
	# }
	my $session = Plack::Session->new($c->req->env);

	# TODO
	my $todo = $self->create_todo({
			user_id => $session->get('user_id'),
			user_name => $session->get('user_name'),
			content => $c->req->param('content'),
			due => $c->req->param('due'),
			done => $c->req->param('done'),
		});

	$c->render_json({todo => $todo});
};

get '/todos/search' => sub {
	my ($self, $c) = @_;

	my $session = Plack::Session->new($c->req->env);
	my $todos = $self->search_todo($session->get('user_id'));
	$c->render_json({todos => $todos});
};

router 'PUT' => '/todos/update' => sub {
	my ($self, $c) = @_;

	my $session = Plack::Session->new($c->req->env);

	# TODO
	my $todo = $self->update_todo({
			user_id => $session->get('user_id'),
			user_name => $session->get('user_name'),
			todo_id => $c->req->param('todo_id'),
			content => $c->req->param('content'),
			# due => $c->req->param('due'),
			done => $c->req->param('done'),
		});
	$c->render_json({todo => $todo});
};

router 'PUT' => '/todos/update-done-only' => sub {
	my ($self, $c) = @_;

	my $session = Plack::Session->new($c->req->env);

	my $todo = $self->update_done_only({
			user_id => $session->get('user_id'),
			user_name => $session->get('user_name'),
			todo_id => $c->req->param('todo_id'),
			done => $c->req->param('done'),
		});
	return $c->render_json({todo => $todo});
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
	my $user_name = $c->req->param('user_name');
	my $email = $c->req->param('email');
	my $password = $c->req->param('password');

	my $user_id = $self->create_user($user_name, $email, $password);

	my $session = Plack::Session->new($c->req->env);
	$session->set('user_id', $user_id);
	$session->set('user_name', $user_name);
	$c->redirect('/todos'); 
};

post '/register/validate' => sub {
	my ($self, $c) = @_;
	my $user_name = $c->req->param('user_name');

	if ($self->user_name_exists($user_name)) {
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
	my $user_name = $c->req->param('user_name');
	my $password = $c->req->param('password');

	my $user_id = $self->check_user_name_and_password($user_name, $password);
	if (!$user_id) {
		return $c->render_json(JSON::false);
	}

	my $session = Plack::Session->new($c->req->env);
	$session->set('user_id', $user_id);
	$session->set('user_name', $user_name);

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
		$self->{_db} = KoList::Model->new(connect_info => [
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
	my ($self, $todo) = @_;
	$todo->{content} //= "";
	my $row = $self->db->insert('todos', {
			user_id => $todo->{user_id}, 
			user_name => $todo->{user_name},,
			content => $todo->{content},
			due => $self->current_time, # TODO
			done => 0, # TODO
			created_at => $self->current_time,
			updated_at => $self->current_time,
		});
	return \%{$row->get_columns};
}

# TODO
sub search_todo {
	my ($self, $user_id) = @_;
	my $itr = $self->db->search('todos', 
		{
			user_id => $user_id,
		}, 
		{
			order_by => {'created_at' => 'DESC'},
		});

	my @rows;
	while (my $row = $itr->next) {
		push(@rows, $row->get_columns);
	}
	return \@rows;
}

sub update_todo {
	my ($self, $todo) = @_;
	$todo->{content} //= "";
	my $update_row_count = $self->db->update('todos',
		{
			user_id => $todo->{user_id},
			user_name => $todo->{user_name},
			content => $todo->{content},
			due => $self->current_time,
			done => $todo->{done} + 0,
			updated_at => $self->current_time,
		},
		{
			id => $todo->{todo_id},
		},
	);
	my $row = $self->db->single('todos', {
			id => $todo->{todo_id},
		});
	return \%{$row->get_columns};
}

sub update_done_only {
	my ($self, $todo) = @_;
	my $updated_row_count = $self->db->update('todos',
		{
			user_id => $todo->{user_id},
			user_name => $todo->{user_name},
			done => $todo->{done} + 0,
		},
		{
			id => $todo->{todo_id},
		},
	);
	my $row = $self->db->single('todos', {
			id => $todo->{todo_id},
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

sub user_name_exists {
	my ($self, $user_name) = @_;

	my $row = $self->db->single('users', {
			name => $user_name,
		});
	return $row ? 1 : 0;
}

sub check_user_name_and_password {
	my ($self, $user_name, $password) = @_;

	my $row = $self->db->single('users', {
			name => $user_name,
			password => Digest::SHA::sha1_hex($user_name . $password),
		});

	return $row ? $row->get_column('id') : 0;
}

sub create_user {
	my ($self, $user_name, $email, $password) = @_;

	my $row = $self->db->insert('users', {
			id => Data::GUID->new->as_base64_urlsafe,
			name => $user_name,
			email => $email,
			password => Digest::SHA::sha1_hex($user_name . $password),
			created_at => $self->current_time,
		});

	return $row->get_column('id');
}

# Utility ================================================================== 

sub current_time {
	my ($self) = @_;
	return DateTime->now(time_zone => 'Asia/Tokyo');
}

1;
