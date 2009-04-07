/*
 * Author:: Johannes Krude
 * Copyright:: (c) Johannes Krude 2008
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
#include <string.h>
#include <stdio.h>

static size_t do_read(FILE *stream, char *buffer, size_t size)
{
	size_t res;
	res= fread(buffer, 1, size, stream);
	if (ferror(stream)) {
		rb_sys_fail("read_until_delimiter_io(read)");
	}
	return res;
}

static size_t do_write(FILE *stream, char *buffer, size_t size)
{
	size_t res;
	res= fwrite(buffer, 1, size, stream);
	if (ferror(stream)) {
		rb_sys_fail("read_until_delimiter_io(write)");
	}
	return res;
}

static VALUE t_read(VALUE self, VALUE in, VALUE out, VALUE delimiter)
{
	FILE *source;
	FILE *destination;
	char *buffer= StringValueCStr(delimiter);
	size_t size= strlen(buffer)+2;
	char *deli= malloc(size);
	deli[0]= '\n';
	strcpy(deli+1, buffer);
	buffer= malloc(size);
	source= RFILE(in)->fptr->f;
	destination= RFILE(out)->fptr->f;

	size_t buf_s;
	while ((buf_s= do_read(source, buffer, size)) == size) {
		char *found= buffer;
		while ((found= memchr(found, '\r', size-(found-buffer))+1) != NULL+1) {
			if (memcmp(found, deli, size-(found-buffer)) == 0) {
				do_write(destination, buffer, found-buffer-1);
				if ((buf_s= do_read(source, buffer, found-buffer-1)) != found-buffer-1) {
					do_write(destination, buffer, buf_s);
					free(buffer);
					return Qnil;
				}
				if (memcmp(buffer, deli+(size-(found-buffer)), found-buffer-1) == 0) {
					free(buffer);
					return Qnil;
				} else {
					do_write(destination, found-1, size-(found-buffer-1));
					if ((buf_s= do_read(source, found-1, size-(found-buffer-1))) != size-(found-buffer-1)) {
						do_write(destination, buffer, buf_s);
						free(buffer);
						return Qnil;
					}
					found= buffer;
				}
			}
		}
		do_write(destination, buffer, size);
	}
	do_write(destination, buffer, buf_s);
	free(buffer);
	return Qnil;
}

VALUE M_filehosting;
VALUE C_web;

/*
 * The part of web which handles a lot of data
 */
void Init_web_c()
{
	M_filehosting= rb_define_module("FileHosting");
	C_web= rb_define_class_under(M_filehosting, "Web", rb_cObject);
	rb_define_singleton_method(C_web, "read_until_delimiter_io", t_read, 3);
}
