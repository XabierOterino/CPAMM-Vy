# @version 0.3.6
from vyper.interfaces import ERC20

event LiquidityAdded:
    account:indexed(address)
    shares:uint256

event LiquidityRemoved:
    account:indexed(address)
    shares:uint256


tokens:public(address[2])
reserves:public(uint256[2])

balances: public(HashMap[address, uint256])
totalSupply:public(uint256)

#constructor
@external
def __init__(_token0:address , _token1:address):
    self.tokens[0] = _token0
    self.tokens[1] = _token1

@external
def swap(i:uint256 , j:uint256 , dx:uint256, minDy:uint256):
    #pull funds
    assert i!=j,"Invalid token"
    ERC20(self.tokens[i]).transferFrom(msg.sender ,self , dx)
    
    #calculate amount out
    dx_fee:uint256 = dx * 997 / 1000 
    dy:uint256= self.reserves[j] * dx_fee / (self.reserves[i] + dx_fee)
    assert dy>=minDy  ,"dy<minDy"

    #push funds and update reserves
    ERC20(self.tokens[j]).transfer(msg.sender , dy)
    self._update(ERC20(self.tokens[i]).balanceOf(self) , ERC20(self.tokens[j]).balanceOf(self))


@external 
def addLiquidity(a0:uint256 , a1:uint256 , minS:uint256):
    assert a0 / a1 == self.reserves[0] / self.reserves[1] , "Invalid input"
    ERC20(self.tokens[0]).transferFrom(msg.sender ,self , a0)
    ERC20(self.tokens[1]).transferFrom(msg.sender ,self , a1)
    shares:uint256=0

    if self.totalSupply==0:
        shares = self._sqr(a0 * a1)
    else:
        shares= self._min(a0 * self.totalSupply / self.reserves[0] , a1 * self.totalSupply / self.reserves[1])
    assert shares>=minS , "Not enough shares" 
    self._mint(msg.sender , shares)
    self._update(ERC20(self.tokens[0]).balanceOf(self) , ERC20(self.tokens[1]).balanceOf(self))
    log LiquidityAdded(msg.sender, shares)
    
@external
def removeLiquidity(s:uint256):
    
    assert self.balances[msg.sender]>=s , "Invalid input"
    b0:uint256 = self.reserves[0]
    b1:uint256 = self.reserves[1]

    a0:uint256 = s * b0 / self.totalSupply
    a1:uint256 = s * b1 / self.totalSupply

    ERC20(self.tokens[0]).transfer(msg.sender , a0)
    ERC20(self.tokens[1]).transfer(msg.sender , a1)
    self._burn(msg.sender , s)
    self._update(ERC20(self.tokens[0]).balanceOf(self) , ERC20(self.tokens[1]).balanceOf(self))
    log LiquidityRemoved(msg.sender , s)

#update reserves
@internal
def _update(r0:uint256 , r1:uint256):
    self.reserves[0] = r0
    self.reserves[1] = r1

# mint shares
@internal
def _mint(a:address , s:uint256):
    self.balances[a]+=s
    self.totalSupply+=s

#update shares
@internal
def _burn(a:address , s:uint256):
    self.balances[a]-=s
    self.totalSupply-=s

@internal 
@pure
def _sqr(y:uint256) -> uint256:
    z:uint256=0
    if y > 3:
        z = y
        x:uint256 = y / 2 + 1
        for i in range(max_value(uint256)):
            z = x
            x = (y / x + x) / 2
            if(x>=z):
                break
        
    elif y != 0 :
        z = 1
    return z
    

@internal
@pure
def _min(x:uint256 , y:uint256) -> uint256:
    if x<=y:
        return x
    else:
        return y
    
