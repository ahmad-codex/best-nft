// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ERC721BlackList
{
    event AddedBlackList(address _user);
    event RemovedBlackList(address _user);

    mapping(address => bool) public blacklisted;

    function getBlackListStatus(address _maker) public view returns (bool) {
        return blacklisted[_maker];
    }

    function _addBlackList(address _evilUser) internal virtual {
        blacklisted[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    function _removeBlackList(address _clearedUser) internal virtual {
        blacklisted[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }
}