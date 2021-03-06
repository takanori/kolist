$(document).ready(function() {

	var ksTodos = $('#ks-todos');

	ksTodos.addClass('ks-todos');
	ksTodos.append(
		'<table class="table well">' +
		'<thead><tr><th class="col-md-1"></th><th class="col-md-9">content</th><th class="col-md-2">created_at</th><th class="col-md-1"></th></tr></thead>' +
		'<tbody class="ks-list"></tbody></table>'
	);

	var ksList = ksTodos.find('.ks-list');
	var rawTodos = [];
	var createForm = $('#create-form');

	$.ajax({
		type: 'GET',
		url: '/todos/search',
		success: function(data) {
			if (data.todos) {
				rawTodos = data.todos;
				refreshTodoList(rawTodos);
			} else {
				// debugPrint('Error searching todos.');
			}
		}
	});

	// intro =========================================================================

	var ksHelp = $('#ks-help');
	ksHelp.bind('click', function() {
		startIntro();
	});

	var intro;
	function startIntro(step) {
		intro = introJs();

		intro.setOptions({
			steps: [
				{
					element: document.querySelectorAll('.ks-row')[0].querySelector('.todo-content'),
					intro: 'Double click here to update the content.',
				},
				{
					element: document.querySelectorAll('.delete-btn')[0],
					intro: 'Click this button to delete the entry',
					position: 'left',
				},
			]
		});

		intro.onexit(function() {
			intro = null;
		});

		intro.start();
		return intro;
	}

	// error messages =======================================================================

	var ksError = $('#error-messages');
	function refreshErrorMessages(messages) {
		ksError.empty();
		for (var i = 0; i < messages.length; i++) {
			ksError.append(
				'<div class="alert alert-error">' +
				'	<button type="button" class="close" data-dismiss="alert">x</button>' + messages[i] +
				'</div>'
			);
		}
	}

	// create =======================================================================

	var contentInput = createForm.find('.content-input');
	$('#ks-create').on('click', function() {
		if (!contentInput.val())
			return;

		addNewTodo(createForm.serialize());
		contentInput.focus();
	});

	function addNewTodo(todoData) {
		$.ajax({
			type: 'POST',
			url: '/todos/create',
			data: todoData,
			success: function(data) {
				if (data.error_messages) {
					refreshErrorMessages(data.error_messages);
					return;
				}
				if (data.todo) {
					rawTodos.unshift(data.todo);
					refreshTodoList(rawTodos);
					contentInput.val("");
				}
			},
			dataType: 'json',
		});
	}

	// update =======================================================================

	var contentBeforeEdit = '';
	$(ksList).on('dblclick', '.todo-content', function() {
		// debugPrint('ks-row dblclicked');

		var existingInput = $(ksList).find('.ks-row-input');
		if (existingInput) {
			existingInput.parent().text(contentBeforeEdit);
			existingInput.remove();
		}

		var todoId = $(this).parent().attr('id');
		var contentTd = $(this);
		var todoContent = contentTd.text();

		contentBeforeEdit = todoContent;
		contentTd.text('');

		var updateTextArea = $('<textarea class="col-xs-12 ks-row-input" rows="4">' + htmlEscape(todoContent).replace(/\"/g, /*"*/ '&quot;') + '</textarea>');
		updateTextArea.appendTo(contentTd).focus();
	
		var submitBtn = $('<input type="button" class="update-btn btn btn-primary btn-xs" name="submit-update" value="Submit">').on('click', function() {

			// Update todo
			var ksRowInput = $(this).siblings('.ks-row-input');
			var newContent = ksRowInput.val();
			var newDone = $(this).parent().siblings('td:first').children().prop('checked') ? 1 : 0;

			if (!newContent)
				return;

			$.ajax({
				type: 'PUT',
				url: '/todos/update',
				data: {
					todo_id: todoId,
					content: newContent,
					done: newDone,
				},
				success: function(data) {
					if (data.error_messages) {
						refreshErrorMessages(data.error_messages);
						return;
					}
					if (data.todo) {
						updateCache(data.todo);
						refreshTodoList(rawTodos);
					}
				},
			});
			
			ksRowInput.val('');
			contentInput.focus();

			if (intro) {
				intro.exit();
			}
		});
		updateTextArea.after(submitBtn);

		if (intro) {
			intro.refresh();
		}
	});

	function updateCache(todo) {
		for (var i = 0; i < rawTodos.length; i++) {
			if (rawTodos[i].id == todo.id) {
				rawTodos[i] = todo;
				break;
			}
		}
	}

	// update done only =======================================================================

	$(ksList).on('click', '.done-check', function() {

		var todoId = $(this).parent().parent().attr('id');
		var newDone = $(this).prop('checked') ? 1 : 0;

		$.ajax({
			type: 'PUT',
			url: '/todos/update-done-only',
			data: {
				todo_id: todoId,
				done: newDone,
			},
			success: function(data) {
				if (data.error_messages) {
					refreshErrorMessages(data.error_messages);
					return;
				}
				if (data.todo) {
					updateCache(data.todo);
					refreshTodoList(rawTodos);
				}
			},
		});

	});

	
	// delete =======================================================================

	$(ksList).on('click', '.delete-btn', function() {
		// debugPrint('delete-btn clicked');
		var todoId = $(this).parent().parent().attr('id');
		deleteTodo(todoId);

		if (intro) {
			intro.exit();
		}
	});

	function deleteTodo(todoId) {
		if (!todoId)
			return;
		$.ajax({
			type: 'DELETE',
			url: '/todos/delete',
			data: {
				todo_id : todoId,
			}, 
			success: function(data) {
				if (data.error_messages) {
					refreshErrorMessages(data.error_messages);
					return;
				}
				// debugPrint("success in delete: " + data.todo_id);
				deleteCache(data.todo_id);
				refreshTodoList(rawTodos);
			},
		});
	}

	function deleteCache(todoId) {
		for (var i = 0; i < rawTodos.length; i++) {
			if (rawTodos[i].id == todoId) {
				rawTodos.splice(i, 1);
				break;
			}
		}
	}

	// helper ========================================================================

	function refreshTodoList(todos) {
		// debugPrint('refreshTodoList todos.length: ' + todos.length);
		
		ksList.empty();
		for (var i = 0; i < todos.length; i++) {
			var str = '';
			str += '<tr id="' + todos[i].id + '" class="ks-row">';
			// str += '<td><input type="checkbox" name="done" checked="' + 'false' + '"></td>';
			str += '<td><input class="done-check" type="checkbox" name="done" ';
			if (todos[i].done !== '0') {
				str += 'checked="true"';
			}
			str += '></td>';
			str += '<td class="todo-content';
			if (todos[i].done !== '0') {
				str += ' text-muted';
			}
			str += '">' + htmlEscape(todos[i].content) + '</td>';
			str += '<td><small class="text-muted">' + htmlEscape(todos[i].created_at) + '</small></td>';
			str += '<td><span class="delete-btn"><i class="icon-remove-sign"></i></span></td></tr>';

			ksList.append(str);
		}

		if (todos.length === 0) {
			ksHelp.hide();
		} else if (ksHelp.is(':hidden')) {
			ksHelp.show();
		}
	}

	function htmlEscape(string) {
		if (!string) return;
		return string.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
	}	


	// debug ========================================================================

	/*
	function debugPrint(str) {
		var	area = $('#debug');
		if (!area) return;
		area.val(area.val() + str + '\n');
	}
	*/
});
