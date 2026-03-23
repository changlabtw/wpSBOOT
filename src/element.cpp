#include "element.hpp"

extern bool do_shuffle;

string chomp(string input)
{
	int i;

	if(input[0] == ' ')
	{ 
		for(i = 0; i < (int)input.length(); i++)
		{
			if(input[i] != ' ')
				break;
		}
		input = input.substr(i);
	}
	while(input.find(' ') != string::npos)
		input.erase(input.find(' '),1);

	return input;
}

element_set::element_set(char *file_name)
{
	fstream file;
	int pos, index;
	string str_tmp, name, seq;
	
	file.open(file_name, ios::in);
	if(!file)
	{
		cout << "ERROR: can not open = " << file_name << endl;
		exit(1);
	}
	
	if (file >> num_spe >> len)
	{
	        cout << " Input alignment:" << endl
	                << "\t# of sequence = " << num_spe << endl 
	                << "\t          len = " << len << endl;
	}
	else
	{
	        cout << " ERROR:" << file_name << " does not match Phylip format" << endl;
                exit(1);
	}
	
	vec_ele.resize(num_spe);

	index = 0;
	while(!file.eof())
	{
		getline(file, str_tmp);
		{
			if((int)str_tmp.length() > 0)
			{
				// identify sequene name
				if ((str_tmp[0] != ' ') && (str_tmp.find_first_of(' ') != string::npos))
				{
					pos = str_tmp.find_first_of(' ');
					vec_ele[index].name =  str_tmp.substr(0, pos);
					str_tmp = str_tmp.substr(pos);
				}
				std::transform(str_tmp.begin(), str_tmp.end(), str_tmp.begin(), ::toupper);
				vec_ele[index].seq += chomp(str_tmp);
				index++;
			}
			else
				index = 0;
		}
	}
	file.close();
	//for(int i = 0; i < (int)vec_ele.size(); i++)
	//	cout << vec_ele[i].seq << endl;
}

element_set::~element_set()
{

}

void element_set::output_subsegment(fstream &file, vector<int> index, int begin, int end)
{
	int i, j, index_tmp;
	const int int_small_seq = 10;
	const int name_length = 11;

	for(j = 0; j < num_spe; j++)
	{
		if(begin == 0)
			file << vec_ele[j].name << string(name_length-(int)vec_ele[j].name.length(), ' ');
		else
			file << string(name_length, ' ');

		for(i = begin; i < end; i++)
		{
			index_tmp = index[i];
			if(index_tmp >= len)
			{
				cout << "[ERROR] index = " << index_tmp << " is larger than sequence length = " << len << endl;
				exit(1);
			}

			if(i%int_small_seq == 0)
 			 file << ' ';
			file << vec_ele[j].seq[index_tmp];
		}		
        	file << endl;
	}
       	file << endl;
}

void element_set::output_segment(fstream &file, vector<int> index)
{
	const int seq_length = 60;
	int num_loop = (int)index.size()/60;

	if(do_shuffle)
	{
		random_shuffle( vec_ele.begin(), vec_ele.end() );
	}

	file << string(5,' ') << num_spe << string(5,' ') << (int)index.size() << endl;
	if(num_loop > 0)
	{
		for(int i=0; i < num_loop; i++)
			output_subsegment(file, index, i*seq_length, (i+1)*seq_length);
	}

	output_subsegment(file, index, num_loop*seq_length, (int)index.size());
}
