

tests:
		fd "\.tests\." | xargs -I_ nvim --headless -c 'PlenaryBustedFile _'

