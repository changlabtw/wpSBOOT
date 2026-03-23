.KEEP_STAT:

all: wei_seqboot

Compiler	= g++
FLAGS		= -Wall -D NDEBUG -O2 -std=c++11
LIB		= -lm

SOURCE		= main.cpp element.cpp

OBJECT		=  $(SOURCE:%.cpp=%.o)

wei_seqboot:	$(OBJECT)
			$(Compiler) $(FLAGS) $(OBJECT) -o wei_seqboot $(LIB)
			mv -f wei_seqboot ../.
			
%.o:		%.cpp
			$(Compiler) $(FLAGS) -c $< -o $@
			
clean:
			rm -f *.o

install:
			mv -f ../wei_seqboot ~/bin/.

