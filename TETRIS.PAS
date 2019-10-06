program Tetris;

uses    dos, crt;

{Types declaration} 
type	figure = ^oneFig; {Type for figures}   
		oneFig = record
			arr: array[1..4] of array[1..4] of byte;
			x, y: integer;
			l_offset, r_offset, t_offset, d_offset: byte;
			static: boolean;
		end;
		
		mainWell = ^TetrisWell; {Type for the well}
		TetrisWell = record
			arr: array[0..23] of array[0..11] of byte;
		end;
		
		AIBuffer = ^buf;	{Type for AI commands}
		buf = array[1..10] of char;
{End of type declaration}

{Variables}
var	well: mainWell; {This is a pointer on the Tetris well}
	i, j: integer; {Iterators}
    newF: figure; {New figure pointer}
    curFig, nextFig: figure; {Current and next figure pointer}
    key: char; {Key pressed}
	speed: integer; {Speed of game}
	game_over: boolean; {Game over indicator}
	score: longint; {Current score}
    t: text; {Variable for the file with the best score}
	s: string; {Here will be read the best score}
	sc: longint; {The best score}
	AI_enabled: boolean; {AI switcher}
	keyBuf: AIBuffer; {Buffer for AI commands}
{End of variables}

{Cursor switcher}
procedure console_cursor_off;

var r: registers;

begin
	r.Ah:=1;
	r.Ch:=32;
	Intr($10,r);
end;
{End of cursor switcher}
	
{Frame drawing}
procedure draw_frame;

var	best_score: string;

begin
	TextColor(15);
	gotoxy(39, 1);
	write('TETRIS');
	gotoxy(55, 2);
	write('Score: ');
	gotoxy(55, 3);
	write('Speed: ');
	gotoxy(55, 10);
	write('Next figure:');
	gotoxy(55,19);
	write('Use arrows to move figures');
	gotoxy(55,20);
	write('and space for rotation');
	gotoxy(55, 22);
	write('Press "p" to pause');
	gotoxy(55, 23);
	write('Press "e" to exit');
	gotoxy(55, 24);
	write('Press "a" for AI');
    gotoxy(55, 5);
	Assign(t, 'tetscore.sc');
    Reset(t);
    Read(t, best_score);
	write('Best score: ', best_score);
    Close(t);
	gotoxy(2, 23);
	write('Alexander Ocheretyany, 2016');
	gotoxy(11, 24);
	write('ver.1.0');
end;
{End of frame drawing}

{Well initialization}
procedure well_init(w: mainWell);

var	ii, jj: byte;

begin
	for ii := 0 to 23 do
	begin
		for jj := 0 to 11 do
		begin
			if ((ii <> 0) AND (ii <> 23)) then
			begin
				if ((jj <> 0) AND (jj <> 11)) then w^.arr[ii][jj] := 0
				else w^.arr[ii][jj] := 2; {Walls}
			end else
			if ii = 0 then w^.arr[ii][jj] := 3 else {Roof}
			if ii = 23 then w^.arr[ii][jj] := 4; {Floor}
		end;
	end;
end;
{Finish of the well initialization}

{Offsets setting}
procedure set_Offsets(f: figure);

var	ii,jj: byte;

begin
	
	f^.l_offset := 5;
	f^.r_offset := 5;
	f^.t_offset := 5;
	f^.d_offset := 5;

	ii := 1;
	while((f^.l_offset = 5) AND (ii <> 5)) do
	begin
		for jj := 1 to 4 do
			if(f^.arr[jj][ii] = 1) then f^.l_offset := ii - 1;
		ii := ii + 1;
	end;
			
	ii := 4;
	while((f^.r_offset = 5) AND (ii <> 0)) do
	begin
		for jj := 1 to 4 do
			if(f^.arr[jj][ii] = 1) then f^.r_offset := 4 - ii;
		ii := ii - 1;
	end;
	
	ii := 1;
	while((f^.t_offset = 5) AND (ii <> 0)) do
	begin
		for jj := 1 to 4 do
			if(f^.arr[ii][jj] = 1) then f^.t_offset := ii - 1;
		ii := ii + 1;
	end;
	
	ii := 4;
	while((f^.d_offset = 5) AND (ii <> 0)) do
	begin
		for jj := 1 to 4 do
			if(f^.arr[ii][jj] = 1) then f^.d_offset := 4 - ii;
		ii := ii - 1;
	end;	
end;
{End of offsets setting}

{Check}
function check(f: figure; where: string): boolean;

var	tmp_x, tmp_y: integer;
	ii, jj: byte;
	allowed: boolean;
	top_off, down_off, left_off, right_off: integer;

begin
	allowed := True;
	tmp_y := f^.y;
    tmp_x := f^.x;
	top_off := 1 + f^.t_offset;
	down_off := 4 - f^.d_offset;
	left_off := 1 + f^.l_offset;
	right_off := 4 - f^.r_offset;

	if(where = 'left') then tmp_x := f^.x - 1
	else if(where = 'right') then tmp_x := f^.x + 1
	else if(where = 'down') then tmp_y := f^.y + 1;
	
	{Compare with the well}
    if((4 - f^.d_offset >= 1 + f^.t_offset) AND (4 - f^.d_offset > 0)) then
    begin
		for ii := top_off to down_off do
		begin
			for jj := left_off to right_off do
			begin
				if((tmp_y + ii - 1 - f^.t_offset >= 0) AND (tmp_y + ii - 1 - f^.t_offset <= 23)) then
				begin
					if((tmp_x -f^.l_offset + jj - 1 >= 0) AND (tmp_x -f^.l_offset + jj - 1 <= 11)) then
					begin
						if(well^.arr[tmp_y + ii - 1 - f^.t_offset][tmp_x -f^.l_offset + jj - 1] + f^.arr[ii][jj] > 1) then
						begin
							allowed := False;
							break;
						end;
					end;
				end;
			end;
		end;
    end;
	check := allowed;
end;
{End of check}

{Figure generation}
function newFigure: figure;

var	numOfFigure: integer;
    ii, jj: byte;
	Fig: figure;

begin
	Randomize; {Start the random number generator}
    numOfFigure := Random(7) + 1; {Generates a random value between 1 and 7}
	new(Fig);
	
	{Initialization}
    for ii := 1 to 4 do
        for jj := 1 to 4 do Fig^.arr[ii][jj] := 0;

    Case numOfFigure of
    1:
        begin
			Fig^.arr[1][3] := 1; {   Figure   }
			Fig^.arr[2][3] := 1; {            }
			Fig^.arr[3][3] := 1; {    ####    }
			Fig^.arr[4][3] := 1; {            }
		end;
	2:
		begin
			Fig^.arr[3][1] := 1; {   Figure   }
			Fig^.arr[3][2] := 1; {            }
			Fig^.arr[2][2] := 1; {     ##     }
			Fig^.arr[2][3] := 1; {    ##      }
		end;
	3:
		begin
			Fig^.arr[4][2] := 1; {   Figure   }
			Fig^.arr[3][2] := 1; {            }
			Fig^.arr[3][3] := 1; {    ##      }
			Fig^.arr[2][3] := 1; {     ##     }
		end;
	4:
		begin
			Fig^.arr[2][1] := 1; {   Figure   }
			Fig^.arr[3][1] := 1; {            }
			Fig^.arr[3][2] := 1; {    ###     }
			Fig^.arr[4][1] := 1; {     #      }
        end;
    5:
        begin
            Fig^.arr[4][3] := 1; {   Figure   }
            Fig^.arr[3][3] := 1; {            }
            Fig^.arr[2][3] := 1; {    ###     }
            Fig^.arr[2][2] := 1; {    #       }
        end;
    6:
        begin
            Fig^.arr[4][2] := 1; {   Figure   }
            Fig^.arr[3][2] := 1; {            }
            Fig^.arr[2][2] := 1; {    ###     }
            Fig^.arr[2][3] := 1; {      #     }
        end;
    7:
        begin
            Fig^.arr[2][2] := 1; {   Figure   }
            Fig^.arr[2][3] := 1; {            }
            Fig^.arr[3][2] := 1; {     ##     }
            Fig^.arr[3][3] := 1; {     ##     }
        end;
	end;
	 
	Fig^.x := 5;
	Fig^.y := 1;
	Fig^.static := False;
	
	set_Offsets(Fig);

	
	if(NOT check(curFig, 'down')) then game_over := True;
	
	newFigure := Fig;
end;
{End of figure generating}

{Well draw procedure}
procedure DrawWell(w: mainWell; c: byte); {If c = 0 then draw the whole Well, if c = 1 then draw only its part}

var	start, stop: integer;
	ii, jj: byte;

begin
	TextColor(9);
	if(c = 0) then
	begin
		start := 0;
		stop := 23;
	end else 
	begin
		start := curFig^.y;
		stop := curFig^.y + 3;
        if stop > 23 then stop := 23;
	end;
	
	for ii := start to stop do
	begin
		gotoxy(30, ii + 2);
		for jj := 0 to 11 do
		begin
			if w^.arr[ii][jj] = 0 then
			begin
				TextColor(2);
				write('.');
			end else
			if w^.arr[ii][jj] = 1 then
			begin
				TextColor(10);
				write('#');
			end else
			if w^.arr[ii][jj] = 2 then
			begin
				TextColor(9);
				write('|');							
			end else if w^.arr[ii][jj] = 3 then
			begin
				TextColor(9);
				if jj <> 11  then write('__') else write('_');
			end
			else if w^.arr[ii][jj] = 4 then
			begin
				TextColor(9);
				if jj <> 11 then write('^^') else write('^');
			end;
			if ((ii <> 23) AND (ii <> 0)) then
			begin
				TextColor(9);
				write(' ');
			end;
		end;
	end;
	
	TextColor(White);
	gotoxy(67, 2);
	write(score);
	gotoxy(67, 3);
	write(speed);
end;
{The end of well draw procedure}

{Checking of row completeness}
procedure check_complete;

var	gap, element: boolean;
	ii, jj, kk: byte;

begin
	ii := 22;
	
	while(ii > 0) do
	begin
		gap := False;
		element := False;
		
		for jj := 1 to 10 do
		begin
			if(well^.arr[ii][jj] = 0) then gap := True else element := True;
		end;
		
		if((gap = False) AND (element = True)) then
		begin
			for kk := ii downto 2 do
			begin
				for jj := 1 to 10 do
				begin
					well^.arr[kk][jj] := well^.arr[kk - 1][jj];
				end;
			end;
			score := score + 1;
			if(score mod 10 = 0) then speed := speed + 1;
			DrawWell(well, 0);
		end else
		if((gap = True) AND (element = False)) then ii := 0 else ii := ii - 1;
	end;
	DrawWell(well, 0);
end;
{End of checking of row completeness}

{Figure draw procedure}
procedure DrawFigure;

var	ii, jj, cur_x, cur_y: byte;

begin
	cur_x := curFig^.x * 2;
	cur_y := curFig^.y + 2;
	
	for ii := 1 to 4 - curFig^.t_offset - curFig^.d_offset do
	begin
		for jj := 1 to 4 - curFig^.l_offset - curFig^.r_offset do
		begin
			gotoxy(30 + cur_x + ((jj - 1) * 2), cur_y + (ii - 1));
			if(curFig^.arr[ii + curFig^.t_offset][jj + curFig^.l_offset] = 1) then
			begin
				TextColor(10);
				write('#');
				TextColor(Black);
			end;
		end;
	end;
end;
{The end of figure draw procedure}

{Move}
procedure move(b: char);

begin
	if b = 'K' then {If 'Left' pressed}
	begin		
		if(check(curFig, 'left')) then
		begin
			DrawWell(well, 0);
			curFig^.x := curFig^.x - 1;
			if(check(curFig, 'down')) then curFig^.static := False;
		end;
	end
	else if b = 'M' then {If 'Right' pressed}
	begin
		if(check(curFig, 'right')) then
		begin
			DrawWell(well, 0);
			curFig^.x := curFig^.x + 1;
			if(check(curFig, 'down')) then curFig^.static := False;
		end;
	end else if b = 'P' then {If 'Down' pressed}
	begin
		while(check(curFig, 'down')) do
		begin
			DrawWell(well, 0);
			curFig^.y := curFig^.y + 1;
			DrawFigure;
		end;
	end;
	DrawFigure;
end;
{End of movement}

{Rotate procedure}
procedure Rotate;

var     tmp, same: array[1..4] of array[1..4] of byte;
        ii, jj: byte;

begin
	{Initialization}
	for ii := 1 to 4 do
	begin
		for jj := 1 to 4 do
		begin
			tmp[ii][jj] := curFig^.arr[ii][jj];
			same[ii][jj] := curFig^.arr[ii][jj];
			curFig^.arr[ii][jj] := 0;
		end;
	end;
		
	{Rotation}
	for ii := 1 to 4 do
	begin
		for jj := 1 to 4 do
		begin
			curFig^.arr[ii][jj] := tmp[jj][4 - (ii - 1)];
		end;
	end;
	set_Offsets(curFig);
	
	if(NOT check(curFig, 'rotate')) then
	begin
		for ii := 1 to 4 do
			for jj := 1 to 4 do
			begin
				curFig^.arr[ii][jj] := same[ii][jj];
			end;
		set_Offsets(curFig);
	end;
	
	if(check(curFig, 'down')) then curFig^.static := False;
	
	DrawWell(well, 1);
end;
{The end of rotation}

{Move down}
procedure Down;

var	ii, jj: byte;

begin
	if(check(curFig, 'down')) then
	begin
		DrawWell(well, 1);
		curFig^.y := curFig^.y + 1;
		DrawFigure;
	end else curFig^.static := True;
end;
{End of moving down}

{Score calculation}
function wScore(wCopy: mainWell): real;

var	ii, jj: byte;
    aggregate_height, complete_lines, holes, bumpiness, b1, b2: integer;
	
begin
	aggregate_height := 0;
	complete_lines := 0;
	holes := 0;
	bumpiness := 0;
	b1 := 0;
	b2 := 0;
	
	{Aggregate height score}
    for jj := 1 to 10 do
    begin
        ii := 1;
        while ii <> 23 do
        begin
            if wCopy^.arr[ii][jj] = 1 then
            begin
                aggregate_height := aggregate_height + (23 - ii);
                ii := 23;
            end else ii := ii + 1;
        end;
    end;
	
	{Width score}
	for ii := 1 to 22 do
	begin
		jj := 1;
		while jj <> 11 do
		begin
			if wCopy^.arr[ii][jj] = 1 then
			begin
				if jj = 10 then complete_lines := complete_lines + 1;
				jj := jj + 1;
			end else jj := 11;
		end;
	end;
	
	{Holes}
	for jj := 1 to 10 do
	begin
		for ii := 22 downto 2 do
		begin
			if ((wCopy^.arr[ii][jj] = 0) AND (wCopy^.arr[ii - 1][jj] = 1)) then
			begin
				holes := holes + 1;
			end;
		end;
	end;
	
	{Bumpiness}
	for jj := 1 to 9 do
	begin
		b1 := b2;
		b2 := 0;
		
		if jj = 1 then
		begin
			ii := 1;
			while ii <> 23 do
			begin
				if wCopy^.arr[ii][jj] = 1 then
				begin
					b1 := 23 - ii;
					ii := 23;
				end else ii := ii + 1;
			end;
		end;
		
		ii := 1;
		while ii <> 23 do
		begin
			if wCopy^.arr[ii][jj + 1] = 1 then
            begin
                b2 := 23 - ii;
                ii := 23;
            end else ii := ii + 1;
		end;
		
		b1 := b1 - b2;
		
		if b1 < 0 then b1 := -b1;
		
		bumpiness := bumpiness + b1;
	end;
	
    wScore := -0.510066 * aggregate_height + 0.760666 * complete_lines + -0.35663 * holes + -0.184483 * bumpiness;
end;
{End of score calculation}

{AI}
function AI: AIBuffer;

var	buffer: AIBuffer; {Buffer for movements}
	wCopy: mainWell;
	ii, jj, kk, bb: byte;
	test, tmp: figure;
	curScore, bestScore: real;
	start, stop, best_x: integer;
	numberOfRotations: byte;

begin
	new(buffer); {Space allocation for a key buffer}
	for ii := 1 to 10 do buffer^[ii] := 'z'; {Buffer initialization}
	new(wCopy); {Space allocation for a well's copy}
	
	bestScore := - 100000; {Score initialization}
	curScore := 0; {Current score}
	numberOfRotations := 0;
	
	{Getting of the current figure's copy}
	new(test);	
	for ii := 1 to 4 do
		for jj := 1 to 4 do test^.arr[ii][jj] := curFig^.arr[ii][jj];
	test^.x := curFig^.x;
	test^.y := curFig^.y;
	set_Offsets(test);
	
	start := test^.x;
	stop := test^.x;

	for bb := 1 to 4 do
	begin
	
		test^.x := curFig^.x;
		test^.y := curFig^.y;
	
		while(check(test, 'left')) do test^.x := test^.x - 1;
		
		start := start + test^.x;
		test^.x := start - test^.x;
		start := start - test^.x;
		
		while(check(test, 'right')) do test^.x := test^.x + 1;
		
		stop := stop + test^.x;
		test^.x := stop - test^.x;
		stop := stop - test^.x;
	
		for kk := start to stop do
		begin
			
			test^.x := kk;
			test^.y := curFig^.y;
			
			{Getting of a well's copy}
			for ii := 0 to 23 do
			begin
				for jj := 0 to 11 do
				begin
					wCopy^.arr[ii][jj] := well^.arr[ii][jj];
				end;
			end;
		
			while(check(test, 'down')) do
			begin
				test^.y := test^.y + 1;
			end;
			
			{Adding of the figure to the well's copy}
			for ii := 1 to 4 do
			begin
				for jj := 1 to 4 do
				begin
					if(test^.arr[ii][jj] = 1) then
					begin
						wCopy^.arr[test^.y + (ii - 1) - test^.t_offset][test^.x + (jj - 1) - test^.l_offset] := test^.arr[ii][jj];
					end;
				end;
			end;
			
			{DrawWell(wCopy, 0);}
			
			{Score calculation}
			curScore := wScore(wCopy);
			if(curScore > bestScore) then
			begin
				bestScore := curScore;
				best_x := kk;
				numberOfRotations := bb - 1;
			end;
		end;
		
		{ROTATION}
		{Initialization}
		for ii := 1 to 4 do
		begin
			for jj := 1 to 4 do
			begin
				tmp^.arr[ii][jj] := test^.arr[ii][jj];
				test^.arr[ii][jj] := 0;
			end;
		end;
			
		{Rotation}
		for ii := 1 to 4 do
		begin
			for jj := 1 to 4 do
			begin
				test^.arr[ii][jj] := tmp^.arr[jj][4 - (ii - 1)];
			end;
		end;
		set_Offsets(test);
		
		if(check(test, 'down')) then test^.static := False;	
		if((bb = 1) OR (bb = 3)) then
		begin
			Down;
			DrawFigure;
		end;		
	end;
	
	ii := 0;
	
	if(numberOfRotations <> 0) then
	begin
		for ii := 1 to numberOfRotations do buffer^[ii] := ' ';
	end;
	
	ii := ii + 1;
	
	if(curFig^.x - best_x > 0) then
	begin
		for jj := 1 to curFig^.x - best_x do
		begin
			buffer^[ii] := 'K';
			ii := ii + 1;
		end;
	end else
	
	if(curFig^.x - best_x < 0) then
	begin
		for jj := 1 to best_x - curFig^.x do
		begin
			buffer^[ii] := 'M';
			ii := ii + 1;
		end;
	end;
	
	AI := buffer;
end;
{End of AI}

{Body of the program}
begin
	console_cursor_off; {Switch off the cursor}

	speed := 1; {Starting speed}
	score := 0; {Starting score}

	new(well); {Space allocation for the well}
	well_Init(well); {Well initialization}

    Directvideo := True;
    ClrScr; {Clear the screen}
	curFig := newFigure; {Generate new figure}
    TextBackground(Black);
	draw_frame; {Add frame with instructions}
	DrawWell(well, 0);	
	game_over := False;
	AI_enabled := False;

    while key <> 'e' do {While not exit}
    begin
		{Getting of the next figure}
		nextFig := newFigure;
		TextColor(10);
		for i := 1 to 4 do
		begin
			for j := 1 to 4 do
			begin
				gotoxy(58 + (j - 1) * 2, 12 + (i - 1));
				if curFig^.arr[i][j] = 1 then write(' ');
				gotoxy(58 + (j - 1) * 2, 12 + (i - 1));
				if nextFig^.arr[i][j] = 1 then write('#');
			end;
		end;			
		
		while ((curFig^.static = False) AND (NOT game_over)) do
		begin
 			DrawFigure;
			if(AI_enabled) then Delay(0)
			else if speed < 40 then Delay(400 - speed * 10) else Delay(0); {Time gap between movements}
			
			if ((AI_enabled) AND (keyBuf = nil)) then
			begin
				gotoxy(11,10);
				TextColor(Yellow);
				write('AI MODE');
				keyBuf := AI;
				gotoxy(12,11);
			end;
			
			if(NOT AI_enabled) then begin
				gotoxy(11,10);
				TextColor(Black);
				write('AI MODE');
			end;
			
			if keyBuf <> nil then
			begin
				repeat
					begin
						DrawFigure;
						key := keyBuf^[1];
						for i := 1 to 9 do keyBuf^[i] := keyBuf^[i + 1];
						case key of
						' ': Rotate;
						'M': move(key);
						'K': move(key);
						'z':
							begin
								Move('P');
								curFig^.static := True;
								Dispose(keyBuf);
								keyBuf := nil;
							end;
						end;
					end;
				until keyBuf^[1] = keyBuf^[2];
			end;
			
 			while(KeyPressed) do
			begin
 				DrawFigure;
				key := ReadKey;
                if key = #0 then key := ReadKey;
				case key of
				' ': Rotate;
				'e':
					begin
						Dispose(well);
						Dispose(curFig);
						ClrScr;
						exit;
					end;
				'M': move(key);
				'K': move(key);
				'P': move(key);
				'p':
					begin
						TextColor(White);
						gotoxy(39, 12);
						TextColor(Yellow);
						write('PAUSE');
						gotoxy(35, 14);
						TextColor(White);
						write('Press any key');
						gotoxy(36, 15);
						write('to continue');
						key := ReadKey;
						DrawWell(well, 0);
					end;
				'a':
					begin
						if AI_enabled then
						begin
							AI_enabled := False;
							if keyBuf <> nil then
							begin
								Dispose(keyBuf);
								keyBuf := nil;
							end;
						end	else AI_enabled := True;
					end;
				end;
   			end;
			Down; {Let the figure to fall down}
 		end;
		{Adding of the current figure to the well}
		if(NOT game_over) then 
		begin
			for i := 1 to 4 do
				for j := 1 to 4 do
					if(curFig^.arr[i][j] = 1) then
					begin
						well^.arr[curFig^.y + (i - 1) - curFig^.t_offset][curFig^.x + (j - 1) - curFig^.l_offset] := curFig^.arr[i][j];
					end;
			check_complete;
		end else
		begin
		{If game is over record the best score}
		for i := 1 to 22 do
			for j := 1 to 10 do
			begin
				well^.arr[i][j] := 1;
			end;
			DrawWell(well, 0);
                        Assign(t, 'tetscore.sc');
                        Reset(t);
						Read(t, s);
						Val(s, sc, i);
                        if score > sc then
						begin
							Close(t);
							Rewrite(t);
							Write(t, score);
						end;
                        Close(t);
			key := ReadKey;
			Dispose(well);
			Dispose(curFig);
			ClrScr;
			exit;
		end;
		curFig := nextFig;
	end;
end.
{The end of the program}