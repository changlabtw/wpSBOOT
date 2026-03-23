//2012-July-11
#include <iostream>
#include <fstream>
#include <random>
#include <math.h>
#include <ctime>
#include <vector>
#include "element.hpp"
#include <stdio.h>
#include <string.h>

using namespace std;

void parse_command_line(int argc, char **argv, char *aln_f, char *poswei_f);
void read_posWei(char *poswei_f, vector<double> &prob_vec);
void get_rand_by_wei(vector<double> probabilities, int size, int limit, vector<int> &pos_vec);
void get_by_wei(vector<double> probabilities, int limit, vector<int> &pos_vec);
                                              
int replicate_num;
float sam_pro;
bool do_shuffle;
bool random_sample;

void exit_with_help()
{
	printf(
		"Usage: wei_seqboot [options] msa.phylip posWei_file(as probability)\n"
		"options:\n"
		" -n replicate_num: the number of replicates (def. 100)\n"
		" -r random_sample: randomly sample column or not; 0-NO, 1-YES (def. 1)\n"
		" -p replicate_proportion: 0~1, set the proportion of the partial sampling (def. 1)\n"
		" -s shuffle: shuffle the order of sequence or not (def. 0)\n"
		"output:\n"
		" outfile: file contains replicate, naming from phylip\n"
	);
	exit(0);
}

int main(int argc, char *argv[])
{
	int i;
	char aln_f[1024];
	char poswei_f[1024];
 	vector<double> prob_vec;
	
	cout << "[BEGIN]Local-bootstrap" << endl;
//INPUT
	parse_command_line(argc, argv, aln_f, poswei_f);
	//read PHYLIP alignement
	element_set input_ele(aln_f);
	//read weight file
	read_posWei(poswei_f, prob_vec);

	fstream file;
	file.open("outfile", ios::out);
	if(!file)
	{
		cout << "ERROR: can not open outfile" << endl;
		return 1;
	}

	//Start Bootstrap
	int size = (int)round(input_ele.get_len()*sam_pro);
	cout << " Bootstrap:"<<  endl
	     << "\treplicate's number = " << replicate_num << endl
	     << "\treplicate's size   = " << size << endl
	     << " Outfile = outfile "     << endl;
	     
	vector<int> pos_vec;
	for(i = 0; i < replicate_num; i++)
	{
		if(random_sample)
		  get_rand_by_wei(prob_vec, size, input_ele.get_len(), pos_vec);
		else
		  get_by_wei(prob_vec, input_ele.get_len(), pos_vec);
		input_ele.output_segment(file, pos_vec);
	}

	file.close();
	cout << "[END]Local-bootstrap" << endl;
	return 0;
}

void parse_command_line(int argc, char **argv, char *aln_f, char *poswei_f)
{
	int i;
	
	// default values
	sam_pro = 1;
	replicate_num = 100;
	do_shuffle = false;
	random_sample = true;
	
	// parse options
	for(i=1;i<argc;i++)
	{
		if(argv[i][0] != '-') break;
		if(++i>=argc)
			exit_with_help();
		switch(argv[i-1][1])
		{
			case 'n':
				replicate_num = atoi(argv[i]);
				break;
			case 'r':
				random_sample = (atoi(argv[i]) == 1);
				break;	
			case 'p':
				sam_pro = atof(argv[i]);
				break;
			case 's':
				do_shuffle = (atoi(argv[i]) == 1);
				break;
			default:
				fprintf(stderr,"unknown option\n");
				exit_with_help();
		}
	}
	
	// determine filenames
	if((i+1)>=argc)
		exit_with_help();

	strcpy(aln_f, argv[i]);
	strcpy(poswei_f, argv[i+1]);
}

void read_posWei(char *poswei_f, vector<double> &prob_vec)
{
	fstream file;
	string tmp_str;
	double tmp;
	
	file.open(poswei_f, ios::in);
	if(!file)
	{
		cout << "[ERROR] can not open = " << poswei_f << endl;
		exit(1);
	}
	
	while(file >> tmp_str)
	{
	  if (tmp_str == "-")   //score_ascii contain '-' character
	    tmp = 0;
	  else
	    tmp = (double)atof(tmp_str.c_str());

	  prob_vec.push_back(tmp);
	}
	file.close();
}

void get_rand_by_wei(vector<double> probabilities, int size, int limit, vector<int> &pos_vec)
{
	int int_tmp;
	static mt19937 rng(static_cast<unsigned> (time(0)));

	// sample from the distribution
	discrete_distribution<> dist(probabilities.begin(), probabilities.end());
	pos_vec.clear();
	while((int)pos_vec.size() < size)
	{
		int_tmp = dist(rng);
		if((int_tmp>=0)&&(int_tmp<limit))
			pos_vec.push_back(int_tmp);
	}
}

void get_by_wei(vector<double> probabilities, int aln_len, vector<int> &pos_vec)
{
	int replicate_num;
	
	if((int)probabilities.size() != aln_len)
	{
	  cout << "[ERROR] weight size:" << (int)probabilities.size() << " != aln_length:" << aln_len << endl;
	  exit(1);
	}
	  
	for(int i = 0; i < (int)probabilities.size(); i++)
	{
	 replicate_num=(int)probabilities[i];
	 for(int j = 0; j < replicate_num; j++)
	 {
	    pos_vec.push_back(i);
	 }
	}
}
