
/**
 * @file example.c
 */
#include "gaba.h"										/* just include gaba.h */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <inttypes.h>
#include <stdbool.h>
int printer(void *fp, uint64_t len, char c)
{
	return(fprintf((FILE *)fp, "%" PRIu64 "%c", len, c));
}

unsigned char seq_nt4_table[256] = {
	0, 1, 2, 3,  4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4, 
	4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4, 
	4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4,
	4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4, 
	4, 0, 4, 1,  4, 4, 4, 2,  4, 4, 4, 4,  4, 4, 4, 4, 
	4, 4, 4, 4,  3, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4, 
	4, 0, 4, 1,  4, 4, 4, 2,  4, 4, 4, 4,  4, 4, 4, 4, 
	4, 4, 4, 4,  3, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4, 
	4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4, 
	4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4, 
	4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4, 
	4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4, 
	4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4, 
	4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4, 
	4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4, 
	4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4,  4, 4, 4, 4
};

void gaba_helper(gaba_t *ctx, char* ref[], size_t rlen[], char* query[], size_t qlen[], int count){
	#pragma omp for
	for (int i = 0; i< count; i++){
		char const t[64] = { 0 };							/* tail array */

		//int rlen = strlen(ref[i]);
		//int qlen = strlen(query[i]);
		
		uint8_t* ref_ = (uint8_t*)calloc(rlen[i], 1);
		uint8_t* query_ = (uint8_t*)calloc(qlen[i], 1);

		for (int j = 0; j < rlen[i]; ++j)
			ref_[j] = seq_nt4_table[(uint8_t)ref[i][j]];
		for (int j = 0; j < qlen[i]; ++j)
			query_[j] = seq_nt4_table[(uint8_t)query[i][j]];

		for (int j = 0; j < rlen[i]; ++j)
			ref_[j] = ref_[j] < 4? 1<<ref_[j] : 15;
		for (int j = 0; j < qlen[i]; ++j)
			query_[j] = query_[j] < 4? 1<<query_[j] : 15;
		
		struct gaba_section_s asec = gaba_build_section(0, ref_, rlen[i]);
		struct gaba_section_s bsec = gaba_build_section(2, query_, qlen[i]);
		struct gaba_section_s tail = gaba_build_section(4, t, 64);

		/* create thread-local object */
		gaba_dp_t *dp = gaba_dp_init(ctx);
		
		
		// gaba_dp_t *dp_32 = &dp[_dp_ctx_index(32)];			/* dp[1] and dp[2] are narrower ones */
		// gaba_dp_t *dp_16 = &dp[_dp_ctx_index(16)];

		/* init section pointers */
		struct gaba_section_s const *ap = &asec, *bp = &bsec;
		struct gaba_fill_s const *f = gaba_dp_fill_root(dp,	/* dp -> &dp[_dp_ctx_index(band_width)] makes the band width selectable */
			ap, 0,											/* a-side (reference side) sequence and start position */
			bp, 0,											/* b-side (query) */
			UINT32_MAX										/* max extension length */
		);

		/* until X-drop condition is detected */
		struct gaba_fill_s const *m = f;					/* track max */
		while((f->status & GABA_TERM) == 0) {
			if(f->status & GABA_UPDATE_A) { ap = &tail; }	/* substitute the pointer by the tail section's if it reached the end */
			if(f->status & GABA_UPDATE_B) { bp = &tail; }

			f = gaba_dp_fill(dp, f, ap, bp, UINT32_MAX);	/* extend the banded matrix */
			m = f->max > m->max ? f : m;					/* swap if maximum score was updated */
		}

		struct gaba_alignment_s *r = gaba_dp_trace(dp,
			m,												/* section with the max */
			NULL											/* custom allocator: see struct gaba_alloc_s in gaba.h */
		);
		//char *fp = NULL;
		printf("score(%" PRId64 "), path length(%" PRIu64 ")\n", r->score, r->plen);
		//gaba_print_cigar_forward(
		//	printer, (void*) stdout,						/* printer */
		//	r->path,										/* bit-encoded path array */
		//	0,												/* offset is always zero */
		//	r->plen											/* path length */
		//);
		//printf("\n");

		/* clean up */
		gaba_dp_res_free(dp, r);
		gaba_dp_clean(dp);
		//free(fp);
	}

}

int main(int argc, char *argv[]) {
	/* create config */
	gaba_t *ctx = gaba_init(GABA_PARAMS(
		.xdrop = 100,
		GABA_SCORE_SIMPLE(2, 1, 2, 1)					/* match award, mismatch penalty, gap open penalty (G_i), and gap extension penalty (G_e) */
	));


  	FILE* ref_data = fopen(argv[1], "r");
  	FILE* query_data = fopen(argv[2], "r");
  	char* ref[64] = {NULL};
  	char* query[64] = {NULL};	
	size_t readr, readq;
	size_t len[64] = {0};
  	size_t len1[64] = {0};
	int count = 0;

	omp_set_num_threads(32);
	while (true) {
		if (count >= 32){
			#pragma omp parallel 
			{
				gaba_helper(ctx, ref, len, query, len1, count);
			}
			count = 0;
		}
		if ((readr = getline(&ref[count], &len[count], ref_data)) == -1) {
      			break;
   		}
		if ((readq = getline(&query[count], &len1[count], query_data)) == -1) {
			break;
		}
		readr = getline(&ref[count], &len[count], ref_data);
		readq = getline(&query[count], &len1[count], query_data);
		++count;
	}
	 // gaba_dp_t *dp;
	 // struct gaba_alignment_s *r;
	//char const *a = "\x01\x08\x01\x08\x01\x08\0";			/* 4-bit encoded "ATATAT" */
	//char const *b = "\x01\x08\x01\x02\x01\x08";			/* 4-bit encoded "ATACAT" */
	
	
	gaba_clean(ctx);
	
	return 0;
}


// void gaba_helper(gaba_t *ctx, char* ref, size_t rlen, char* query, size_t qlen){
// 	char const t[64] = { 0 };							/* tail array */
	
// 	//int rlen = strlen(ref);
// 	//int qlen = strlen(query);
// 	uint8_t* ref_ = (uint8_t*)calloc(rlen, 1);
// 	uint8_t* query_ = (uint8_t*)calloc(qlen, 1);

// 	for (int i = 0; i < rlen; ++i)
// 		ref_[i] = seq_nt4_table[(uint8_t)ref[i]];
// 	for (int i = 0; i < qlen; ++i)
// 		query_[i] = seq_nt4_table[(uint8_t)query[i]];

// 	for (int i = 0; i < rlen; ++i)
// 		ref_[i] = ref_[i] < 4? 1<<ref_[i] : 15;
// 	for (int i = 0; i < qlen; ++i)
// 		query_[i] = query_[i] < 4? 1<<query_[i] : 15;

// 	struct gaba_section_s asec = gaba_build_section(0, ref_, rlen);
// 	struct gaba_section_s bsec = gaba_build_section(2, query_, qlen);
// 	struct gaba_section_s tail = gaba_build_section(4, t, 64);

// 	/* create thread-local object */
// 	gaba_dp_t *dp = gaba_dp_init(ctx);
	
// 	/* init section pointers */
// 	struct gaba_section_s const *ap = &asec, *bp = &bsec;
// 	struct gaba_fill_s const *f = gaba_dp_fill_root(dp,	/* dp -> &dp[_dp_ctx_index(band_width)] makes the band width selectable */
// 		ap, 0,											/* a-side (reference side) sequence and start position */
// 		bp, 0,											/* b-side (query) */
// 		UINT32_MAX										/* max extension length */
// 	);

// 	/* until X-drop condition is detected */
// 	struct gaba_fill_s const *m = f;					/* track max */
// 	while((f->status & GABA_TERM) == 0) {
// 		if(f->status & GABA_UPDATE_A) { ap = &tail; }	/* substitute the pointer by the tail section's if it reached the end */
// 		if(f->status & GABA_UPDATE_B) { bp = &tail; }

// 		f = gaba_dp_fill(dp, f, ap, bp, UINT32_MAX);	/* extend the banded matrix */
// 		m = f->max > m->max ? f : m;					/* swap if maximum score was updated */
// 	}

// 	struct gaba_alignment_s *r = gaba_dp_trace(dp,
// 		m,												/* section with the max */
// 		NULL											/* custom allocator: see struct gaba_alloc_s in gaba.h */
// 	);

// 	printf("score(%" PRId64 "), path length(%" PRIu64 ")\n", r->score, r->plen);
	
// 	//gaba_print_cigar_forward(
// 	//	printer, (void*) stdout,						/* printer */
// 	//	r->path,										/* bit-encoded path array */
// 	//	0,												/* offset is always zero */
// 	//	r->plen											/* path length */
// 	//);
	
// 	//printf("\n");

// 	/* clean up */
// 	gaba_dp_res_free(dp, r);
// 	gaba_dp_clean(dp);

// }

// int main(int argc, char *argv[]) {
// 	/* create config */
// 	gaba_t *ctx = gaba_init(GABA_PARAMS(
// 		.xdrop = 100,
// 		GABA_SCORE_SIMPLE(2, 1, 2, 1)					/* match award, mismatch penalty, gap open penalty (G_i), and gap extension penalty (G_e) */
// 	));


//   	FILE* ref_data = fopen(argv[1], "r");
//   	FILE* query_data = fopen(argv[2], "r");
//   	char* ref;
//   	char* query;	
// 	size_t readr, readq;
// 	size_t len = 0;
//   	size_t len1 = 0;
// 	int count = 0;
// 	while (true) {
// 		if ((readr = getline(&ref, &len, ref_data)) == -1) {
//       			break;
//    		}
// 		if ((readq = getline(&query, &len1, query_data)) == -1) {
// 			break;
// 		}
// 		readr = getline(&ref, &len, ref_data);
// 		readq = getline(&query, &len1, query_data);
// 		//ref[strlen(ref)-1] = '\0';
// 		//query[strlen(query)-1] = '\0';
		
// 		gaba_helper(ctx, ref, len, query, len1);
// 		++count;
// 		//printf("%d\n", count);
// 	}
// 	 // gaba_dp_t *dp;
// 	 // struct gaba_alignment_s *r;
// 	//char const *a = "\x01\x08\x01\x08\x01\x08\0";			/* 4-bit encoded "ATATAT" */
// 	//char const *b = "\x01\x08\x01\x02\x01\x08";			/* 4-bit encoded "ATACAT" */
	
// 	gaba_clean(ctx);
	
// 	return 0;
// }

/**
 * end of example.c
 */
