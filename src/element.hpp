#ifndef _ELEMENT_H
#define _ELEMENT_H

#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <algorithm>

using namespace std;

struct element
{
	string name;
	string seq;
};

class element_set
{
	public:	
		element_set(char *file_name);
		~element_set();
		int get_num_spe(){return num_spe;};
		int get_len(){return len;};
		void output_segment(fstream &file, vector<int> index);

	private:
		int num_spe;
		int len;
		vector<element> vec_ele;
		void output_subsegment(fstream &file, vector<int> index, int begin, int end);
};

#endif 	//_ELEMENT_H
