/*
 * Author:: Johannes Krude
 * Copyright:: (c) Johannes Krude 2008 - 2009
 * License:: AGPL3
 *
 * This file is part of filehosting.
 *
 * filehosting is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * filehosting is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with filehosting.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <ruby.h>
#include <rubyio.h>
#include <stdio.h>

VALUE t_do(VALUE self, VALUE in, VALUE out, VALUE size)
{
	rb_check_type(in, T_FILE);
	rb_check_type(out, T_FILE);
	FILE *source;
	if (rb_funcall(rb_eval_string("Socket"), rb_intern("=="), 1, rb_class_of(in)) == Qtrue)
		source= RFILE(in)->fptr->f2;
	else
		source= RFILE(in)->fptr->f;
	FILE *destination;
	if (rb_funcall(rb_eval_string("Socket"), rb_intern("=="), 1, rb_class_of(out)) == Qtrue)
		destination= RFILE(out)->fptr->f2;
	else
		destination= RFILE(out)->fptr->f;
	VALUE result= INT2NUM(0);
	char buffer[1024];
	while ((size == Qnil) || (rb_funcall(result, rb_intern("<"), 1, size) == Qtrue)) {
		size_t done= fread(buffer, 1, sizeof(buffer), source);
		if (ferror(source)) {
			rb_sys_fail("io2io_do(read)");
		}
		fwrite(buffer, 1, done, destination);
		if (ferror(destination)) {
			rb_sys_fail("io2io_do(write)");
		}
		result= rb_funcall(result, rb_intern("+"), 1, INT2NUM(done));
		if (done < sizeof(buffer)) {
			return result;
		}
	}
	return result;
}

VALUE M_io2io;

/*
 * Some functions to put data to the network with high performance.
 */
void Init_io2io_c()
{
	M_io2io= rb_define_module("IO2IO");
	rb_define_module_function(M_io2io, "do_c", t_do, 3);
}
