#define HTTPD_TEST_REQUIRE_APACHE 2

#if CONFIG_FOR_HTTPD_TEST

<Location /random_chunk>
   SetHandler random-chunk
</Location>

#endif

/* ====================================================================
 * The Apache Software License, Version 1.1
 *
 * Copyright (c) 2000-2001 The Apache Software Foundation.  All rights
 * reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. The end-user documentation included with the redistribution,
 *    if any, must include the following acknowledgment:
 *       "This product includes software developed by the
 *        Apache Software Foundation (http://www.apache.org/)."
 *    Alternately, this acknowledgment may appear in the software itself,
 *    if and wherever such third-party acknowledgments normally appear.
 *
 * 4. The names "Apache" and "Apache Software Foundation" must
 *    not be used to endorse or promote products derived from this
 *    software without prior written permission. For written
 *    permission, please contact apache@apache.org.
 *
 * 5. Products derived from this software may not be called "Apache",
 *    nor may "Apache" appear in their name, without prior written
 *    permission of the Apache Software Foundation.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED.  IN NO EVENT SHALL THE APACHE SOFTWARE FOUNDATION OR
 * ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
 * USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
 * OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 * ====================================================================
 *
 * This software consists of voluntary contributions made by many
 * individuals on behalf of the Apache Software Foundation.  For more
 * information on the Apache Software Foundation, please see
 * <http://www.apache.org/>.
 *
 * Portions of this software are based upon public domain software
 * originally written at the National Center for Supercomputing Applications,
 * University of Illinois, Urbana-Champaign.
 */

/*
 * This module is intended to be used for testing chunked encoding.  It
 * generates a whole whack of output using ap_bputc() and ap_bputs().  It
 * also exercises start_chunk() and end_chunk() in buff.c.  To use it
 * you should use a tool like netcat and the src/test/check_chunked
 * tool.  Add something like this to your access.conf file:
 *
 * <Location /rndchunk>
 * SetHandler rndchunk
 * </Location>
 *
 * Then fake requests such as:
 *
 * GET /rndchunk?0,1000000 HTTP/1.1
 * Host: localhost
 *
 * The first arg is the random seed, the second is the number of
 * "things" to do.  You should try a few seeds.
 *
 * You should also edit main/buff.c and change DEFAULT_BUFSIZE (and
 * CHUNK_HEADER_SIZE).  Small values are particularly useful for
 * finding bugs.  Try a few different values.
 *
 * -djg
 */

#include "httpd.h"
#include "http_protocol.h"
#include "http_config.h"
#include "http_main.h"

#define MAX_SEGMENT	32
#define ONE_WEIGHT	(256-32)

static int random_chunk_handler(request_rec *r)
{
    const char *args;
    char *endptr;
    unsigned int seed;
    unsigned int count;
    int i;
    char buf[MAX_SEGMENT + 1];
    unsigned int len;
    apr_size_t total = 0;

    if (strcmp(r->handler, "random-chunk")) {
        return DECLINED;
    }

    if (r->proto_num < HTTP_VERSION(1,1)) {
        return DECLINED;
    }

    r->allowed |= (AP_METHOD_BIT << M_GET);

    if (r->method_number != M_GET) {
	return DECLINED;
    }

    r->content_type = "text/html";		

    if (r->header_only) {
	return OK;
    }

    args = r->args;
    if (!args) {
error:
	ap_rputs("Must include args! ... "
                 "of the form <code>?seed,count</code>", r);
	return 0;
    }

    seed = strtol(args, &endptr, 0);
    if (!endptr || *endptr != ',') {
	goto error;
    }
    ++endptr;
    count = strtol(endptr, &endptr, 0);

    srandom(seed); /* XXX: apr-ize */

    for (i = 0; i < count; ++i) {
	len = random() % (MAX_SEGMENT + ONE_WEIGHT);

	if (len >= MAX_SEGMENT) {
	    ap_rputc((i & 1) ? '0' : '1', r);
            total += 1;
	}
	else if (len == 0) {
            /* 1.x version used to do this; but chunk_filter does now */
#if 0
	    ap_bsetflag(r->connection->client, B_CHUNK, 0);
	    ap_bsetflag(r->connection->client, B_CHUNK, 1);
#endif
	}
	else {
	    memset(buf, '2' + len, len);
	    buf[len] = 0;
	    total += ap_rputs(buf, r);
	}
    }

    ap_rprintf(r, "__END__:%d", total);

    fprintf(stderr, "[mod_random_chunk] sent %d bytes\n", total);

    return 0;
}

static void random_chunk_register_hooks(apr_pool_t *p)
{
    ap_hook_handler(random_chunk_handler, NULL, NULL, APR_HOOK_MIDDLE);
}

module AP_MODULE_DECLARE_DATA random_chunk_module = {
    STANDARD20_MODULE_STUFF, 
    NULL,                  /* create per-dir    config structures */
    NULL,                  /* merge  per-dir    config structures */
    NULL,                  /* create per-server config structures */
    NULL,                  /* merge  per-server config structures */
    NULL,                  /* table of config file commands       */
    random_chunk_register_hooks  /* register hooks                      */
};
